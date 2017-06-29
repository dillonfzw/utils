#! /bin/bash

DEFAULT_entrypoint=dsm60
# san1 has primary MAC 00:e0:4c:7a:e3:a7
# but synology needs to have 00:11:32 prefix
DEFAULT_mac1=00:11:32:7a:e3:a7
DEFAULT_menuentry=bare
DEFAULT_vid=""
DEFAULT_pid=""
DEFAULT_fimg=""

source log.sh
source getopt.sh

if [ ! -f "$fimg" -a ! -b "$fimg" ]; then
    log_error "Image file \"$fimg\" is neither a valid file nor block device. Abort!"
    exit 1
fi

function get_fdev() {
    local fin=$1

    if [ -f "$fin" ]; then
        fdev=`df -m $fin | grep -v ^Filesystem | awk '{print $1}'`
    elif [ -b "$fin" ]; then
        fdev=$fin
    else
        false
    fi && \
    [ -b "$fdev" ] && \
    fdev=/sys/class/block/$(basename `readlink -m $fdev`) && \
    [ -d "$fdev" ] && \
    udevadm info --query=property --path=$fdev | grep -E "^ID_MODEL_ID=|^ID_VENDOR_ID=" | \
    sed -e 's/ID_MODEL_ID=/pid=0x/g' -e 's/ID_VENDOR_ID=/vid=0x/g'
}

[ -z "$vid" -o -z "$pid" ] && \
line=`get_fdev $fimg` && \
if [ -n "$line" ]; then
    eval "$line"
else
    log_error "Cannot get vid/pid of the usb block device which contains the image file, \"$fimg\". Abort!"
    exit 1
fi

mac1=`echo "$mac1" | sed -e 's/://g' | tr 'a-f' 'A-F'`

menuentry_tool='XPEnology Configuration Tool v2.2'
menuentry_bare='XPEnology DS3615xs 6.0.2-8451.5 Baremetal'
saved_entry=`eval "echo \\\$menuentry_$menuentry"`

USER=${USER:-`whoami`}

if [ "$USER" != "root" ]; then
    sudo=sudo
else
    sudo=""
fi

function dsm52() {
    local rc=1
    local ftmpd=`mktemp -d /tmp/update_vpid.XXXXX`
    if $sudo mount -o loop,offset=$((63*512)) $fimg $ftmpd; then
        $sudo sed -i.bak \
            -e 's/vid=0[xX][0-9a-fA-F]\+ /vid='$vid' /g' \
            -e 's/pid=0[xX][0-9a-fA-F]\+ /pid='$pid' /g' \
            $ftmpd/syslinux.cfg && \
        rc=0 && \
        diff -u $ftmpd/syslinux.cfg.bak $ftmpd/syslinux.cfg

        # output for debug
        grep -nHE " vid=0x| pid=0x" $ftmpd/syslinux.cfg
        $sudo umount $ftmpd
    fi
    rmdir $ftmpd 2>/dev/null

    return $rc
}
function dsm60() {
    local rc=1
    local ftmpd=`mktemp -d /tmp/update_vpid.XXXXX`

    local mount_options="offset=$((2048*512))"
    [ ! -b "$fimg" ] && mount_options="loop,$mount_options"

    if $sudo mount -o $mount_options $fimg $ftmpd; then
        $sudo sed -i.bak \
            -e 's/^set vid=.*$/set vid='$vid'/g' \
            -e 's/^set pid=.*$/set pid='$pid'/g' \
            -e 's/^set mac1=.*$/set mac1='$mac1'/g' \
            -e 's/^set default=.*$/set default=\"'"$saved_entry"'\"/g' \
            $ftmpd/grub/grub.cfg && \
        $sudo cp -f $ftmpd/grub/grubenv $ftmpd/grub/grubenv.bak && \
        $sudo grub-editenv $ftmpd/grub/grubenv set saved_entry="$saved_entry" &&
        rc=0 && \
        for FILE in $ftmpd/grub/{grub.cfg,grubenv}; do
            diff -u $FILE.bak $FILE | sed -e "s/^/`basename $FILE` >> /g"
        done

        # output for debug
        grep -nHE "^set sn=|^set vid=|^set pid=|^set mac[0-9]*=|^set default=" $ftmpd/grub/grub.cfg
        grep -nHE "^saved_entry=" $ftmpd/grub/grubenv
        $sudo umount $ftmpd
    fi
    rmdir $ftmpd 2>/dev/null

    return $rc
}

$entrypoint
