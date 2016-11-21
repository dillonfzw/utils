#! /bin/bash

[ "$DEBUG" = "yes" ] && set -x;

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=0.1.0


###############################
# Typical disk partition layout
#
# [root@hadoopn3 mapred]# lsblk
# NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# ...
# sde           8:0    0   1.8T  0 disk 
# ├─sde1        8:1    0   450G  0 part /hadoop/mapred/local_01       <== shuffle
# ├─sde2        8:2    0   1.1T  0 part /hadoop/dfs/dn/disk_01        <== hdfs dn
# └─sde3        8:3    0   300G  0 part /hadoop/dfs/nn/disk_01        <== hdfs nn
# ...

# Comma separated disk list:
# Format 1:
# --------------------------------------------------
# >> [root@hadoopn1 ~]# cat ~/disk.lst
# >> DISK|hadoopn1:sde-meta,sdf-meta,sdg-meta,sdh-meta,sdi,sdj,sdk,sdl,sdm,sdn,sdo,sdp
# >> DISK|hadoopn2:sde-meta,sdf-meta,sdg-meta,sdh-meta,sdi,sdj,sdk,sdl,sdm,sdn,sdo,sdp
# --------------------------------------------------
# Note:
# - "-m, -meta": meta
# - "-d, -data": data, by default if no suffix
# - "-t, -temp": temp
# - "-dt": data + temp, typical hadoop datanode partition layout
# - "-dtm": data + temp + meta, mixed hadoop datanode and namenode
DEFAULT_diskList=~/disk.lst

# disk space reserved for GPFS meta or HDFS name node
DEFAULT_meta_cap=3

# percentage of shuffle/tmp in data disks 
DEFAULT_temp_per=25

# hadoop mount point prefix
DEFAULT_hadoopPrefix=/hadoop

# Type of hadoop dfs
# support: hdfs | gpfs
DEFAULT_dfsType=hdfs

# enforce create if already exists, such as:
# - fs already created
DEFAULT_enforce=false


# constant variable
DEFAULT_dfsDataDirFormat="/dn/disk_%03d"
DEFAULT_dfsNameDirFormat="/nn/disk_%03d"
DEFAULT_nmLocalDirFormat="/yarn/nm/disk_%03d"
DEFAULT_dfsDataDirLabel="_H_DN_%03d"
DEFAULT_dfsNameDirLabel="_H_NN_%03d"
DEFAULT_nmLocalDirLabel="_H_NM_%03d"


function usage() {
    echo "Usage: $PROGNAME [options] -- [redis-benchmark options]" >&2
    echo "Options:" >&2
    echo "    -h|--help                    show this output" >&2
    echo "    -v|--version                 show version" >&2
    echo "         diskList=<path>         disk distribution file for all nodes in the cluster, default to \"$DEFAULT_diskList\"" >&2
    echo "                                 refer to the \"$PROGDIR/disk.lst.sample\" for detailed syntax." >&2
    echo "         meta_cap=<num>          disk capacity which reserved for meta data, unit GB, default to \"$DEFAULT_meta_cap\"" >&2
    echo "         temp_per=<0-100>        percent of disk capacity which reserved for hadoop local temp, default to \"$DEFAULT_temp_per\"" >&2
    echo "         hadoopPrefix=<dir>      hadoop runtime home directory, default to \"$DEFAULT_hadoopPrefix\"" >&2
    echo "         dfsType=dfs | gpfs      type of DFS, default to \"$DEFAULT_dfsType\"" >&2
    echo "         enforce=true | false    do the work enforcely, default to \"$DEFAULT_enforce\"" >&2
    echo >&2
    echo "Example:" >&2
    echo "1). Normal run" >&2
    echo "    $PROGNAME hadoopPrefix=/hadoop meta_cap=5 temp_per=20 dfsType=hdfs enforce=true diskList=/shared/disk.lst" >&2
    echo >&2
    return 0
}

source $PROGDIR/log.sh
source $PROGDIR/getopt.sh


# Parser the disk distribution for current node
if [ ! -f $diskList ]; then
    log_error "File \"$diskList\" does not exist. Abort!"
    exit 1
fi
hostname_admin=`hostname -s|sed -e 's/-dat$//g'`
diskList_line=$(cat $diskList \
               | grep "^DISK|${hostname_admin}:" | cut -d: -f2- | tr ',' '\n' | grep -v "^#")
# filter out meta disks
diskList_meta=$(echo "$diskList_line" | grep -E  "[-][dt]*m[dt]*$|[-]meta$" \
               | sed -e 's/-[mdt]\+$//g' -e 's/-meta$//g' -e 's/-data$//g' -e 's/-temp$//g' | xargs)
# filter out temp disks
diskList_temp=$(echo "$diskList_line" | grep -E  "[-][md]*t[md]*$|[-]temp$" \
               | sed -e 's/-[mdt]\+$//g' -e 's/-meta$//g' -e 's/-data$//g' -e 's/-temp$//g' | xargs)
# filter out data disks
diskList_data=$(echo "$diskList_line" | grep -vE "[-][mt]\+$|[-]meta$|[-]temp$" \
               | sed -e 's/-[mdt]\+$//g' -e 's/-meta$//g' -e 's/-data$//g' -e 's/-temp$//g' | xargs)
# full set of disks
diskList_line=$(echo "$diskList_line" \
               | sed -e 's/-[mdt]\+$//g' -e 's/-meta$//g' -e 's/-data$//g' -e 's/-temp$//g' | xargs)
# log for debug
set | grep "^diskList" | sed -e 's/^/>> /g' | log_lines debug


# >> [root@x3650m2n2 bin]# lsblk --list --noheading -o NAME,MOUNTPOINT /dev/sdk
# >> sdk  
# >> sdk1 /hadoop/yarn/nm/disk_001
# >> sdk2 /hadoop/dfs/dn/disk_001
# >> sdk3 /hadoop/dfs/nn/disk_001
umount_disk() {
    local dsk=$1
    local lines=`lsblk --list --noheading -o NAME,MOUNTPOINT $dsk`
    echo "$lines" | awk 'NF > 1 { print $1,$2; }' \
    | while read dev mntp
    do
        dev=/dev/$dev
        log_debug "Un-mount device $dev from directory $mntp."
        umount $dev
    done
}

# clean existing partition table in target disk
clean_disk() {
    local dsk=$1
    local lines=""
    cmd="sgdisk --zap-all --clear --mbrtogpt $dsk 2>&1"

    umount_disk $dsk

    if ! lines=`eval "$cmd" || eval "$cmd"`; then
        log_error "Fail to clean partition table in disk $dsk" >&2
        echo "$lines" | log_lines info
        false
    fi
}
create_fs() {
#    fsname="hadoop temp"
#    fstype=xfs
#    fsopts="defaults,noatime,nodiratime,inode64,nobarrier"
#    dev_tmp=${dev}1
#    mntp=`printf "$nmLocalDirFormat" $idx`
#    label=`printf "$nmLocalDirLabel" $idx`

    # if target partition was already mounted for some reason, umount it first.
    local line=`grep "^$dev_tmp " /proc/mounts`
    if [ -n "$line" ]; then
        if $enforce; then
            log_warn "\"$dev_tmp\" was already mounted as \"$line\"." >&2
            umount $dev_tmp
        else
            log_error "\"$dev_tmp\" was already mounted as \"$line\"." >&2
            log_error "Please umount it first, or specify \"enforce=true\"!" 2>&1
            exit 1
        fi
    fi

    # handle if target label was already exist.
    if [ -L /dev/disk/by-label/$label ]; then
        local badDev=`readlink -m /dev/disk/by-label/$label`
        if $enforce; then
            log_warn "Label \"$label\" was already marked in device \"$badDev\". Shred it!" 2>&1
            shred -n1 -z -s 1M $badDev
        else
            log_error "Label \"$label\" was already marked in device \"$badDev\". Please clean it first, or specify \"enforce=true\"!" 2>&1
            exit 1
        fi
    fi

    log_info "Create $fstype file system in $fsname partition $dev_tmp." >&2
    lines=`mkfs.$fstype -f -L $label $dev_tmp 2>&1`
    if [ $? -ne 0 ]; then
        log_error "Fail to mkfs.$fstype in device $dev_tmp with following output:"
        echo "$lines" | sed -e "s/^/>> /g" | log_lines debug
        return 1
    fi

    # persistent to /etc/fstab
    if ! grep -sq "LABEL=$label" /etc/fstab; then
        log_info "Add entry to fstab about $fsname partition $dev_tmp as $mntp." >&2
        echo "LABEL=$label $mntp $fstype $fsopts 0 1" >>/etc/fstab
    fi

    # mount partition
    if [ ! -d $mntp ]; then mkdir -p $mntp; fi
    mount LABEL=$label
    if ! mount -v | grep -sq "on $mntp type $fstype"; then
        log_error "Fail to mount $fsname partition $dev_tmp, remove entry from /etc/fstab..." >&2
        sed -i -e "/LABEL=$label /d" /etc/fstab
        return 1
    fi
}


((idx=1))
for disk in $diskList_line
do
    dev=/dev/$disk
    
    for item in meta data temp
    do
        eval "if echo \"\$diskList_${item}\" | grep -sq -w $disk; then ${item}Disk=true; else ${item}Disk=false; fi"
    done
   
    disk_cap=`blockdev --getsz $dev`
    if [ $? -ne 0 ]; then
        log_error "Fail to get block device total size. Ignore device $dev."
        continue
    fi
    disk_ss=`blockdev --getss $dev`

    # reserve first 2048 sectors for system
    ((data_cap=(disk_cap - disk_ss * 2048) >>21))
    if $metaDisk; then
        ((data_cap -= meta_cap))
    fi
    if $tempDisk; then
        ((temp_cap = data_cap * temp_per / 100))
        ((data_cap -= temp_cap))
    fi
    unset disk_cap disk_ss

    # log for debug
    set | grep -E "^data_cap=|^temp_cap=|^meta_cap=" | sed -e "s,^,$dev >> ,g" | log_lines debug

    # clear target disk first
    clean_disk $dev || continue

    # create partitions
    if $tempDisk; then
        log_info "Create shuffle partition on disk \"$dev\"..."
        sgdisk -n 1::+${temp_cap}g -t 0:8300 $dev
    fi
    if $dataDisk; then
        log_info "Create data partition on disk \"$dev\"..."
        sgdisk -n 2::+${data_cap}g -t 0:8300 $dev
    fi
    if $metaDisk; then
        log_info "Create meta partition on disk \"$dev\"..."
        sgdisk -n 3::+${meta_cap}g -t 0:8300 $dev
    fi

    # log for debug: show current partition layout
    sgdisk -p $dev | sed -e "s,^,$disk >> ,g" | log_lines debug

    # create fs on hadoop partitions
    if $tempDisk; then
        fsname="hadoop temp"
        fstype=xfs
        fsopts="defaults,noatime,nodiratime,inode64,nobarrier"
        dev_tmp=${dev}1
        mntp=`printf "${hadoopPrefix}${nmLocalDirFormat}" $idx`
        label=`printf "$nmLocalDirLabel" $idx`

        create_fs
    fi
    if $dataDisk && [ "$dfsType" = "hdfs" ]; then
        fsname="hadoop datanode data"
        fstype=xfs
        fsopts="defaults,noatime,nodiratime,inode64,nobarrier"
        dev_tmp=${dev}2
        mntp=`printf "${hadoopPrefix}${dfsDataDirFormat}" $idx`
        label=`printf "$dfsDataDirLabel" $idx`
    
        create_fs
    fi
    if $metaDisk && [ "$dfsType" = "hdfs" ]; then
        fsname="hadoop namenode data"
        fstype=xfs
        fsopts="defaults,noatime,nodiratime,inode64,nobarrier"
        dev_tmp=${dev}3
        mntp=`printf "${hadoopPrefix}${dfsNameDirFormat}" $idx`
        label=`printf "$dfsNameDirLabel" $idx`
    
        create_fs
    fi

    ((idx+=1))
done
