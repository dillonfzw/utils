#! /bin/bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=1.0.1


# constant variables
USER=${USER:-`whoami`}
HOSTNAME_S=${HOSTNAME_S:-`hostname -s`}
PWD=${PWD:-`pwd`}

sudo_const="sudo -n"
if [ "$USER" != "root" ]; then
    sudo="$sudo_const"
fi


# default values of input parameters
DEFAULT_egoadmin_uid=320776
DEFAULT_egoadmin_uname=egoadmin
DEFAULT_egoadmin_gid=523664
DEFAULT_egoadmin_gname=egoadmin
DEFAULT_BASEPORT=17869
DEFAULT_CLUSTERNAME=cluster_dl
DEFAULT_installerbin=$PWD/cws-2.2.0.0_ppc64le.bin
DEFAULT_entitlement=$PWD/entitlement_file.dat
DEFAULT_cwshome=/opt/ibm/spectrumcomputing
DEFAULT_cwsrole=cn
if [ "$DEFAULT_cwsrole" = "mn" ]; then
    DEFAULT_cwsmn=$HOSTNAME_S
else
    DEFAULT_cwsmn=""
fi


# import common libraries
source $PROGDIR/log.sh
source $PROGDIR/getopt.sh


# logic to valid input parameter
if [ "$cwsrole" = "cn" -a -z "$cwsmn" ]; then
    log_error "You must specify a valid CwS MN, \"cwsmn\", in order to install and setup a CwS CN" >&2
    exit 1
fi


function create_egoadmin() {
    local uid_c=`id -u $egoadmin_uname 2>/dev/null`
    local gid_c=`id -g $egoadmin_gname 2>/dev/null`

    # assert there is no user/group which had been created with different uid/gid
    if [ -n "$uid_c" -a "$uid_c" != "$egoadmin_uid" ]; then
        log_error "User \"$egoadmin_uname\" had already exist and has different uid than \"$egoadmin_uid\", Abort!"
        return 1

    elif [ -n "$gid_c" -a "$gid_c" != "$egoadmin_gid" ]; then
        log_error "Group \"$egoadmin_gname\" had already exist and has different uid than \"$egoadmin_gid\", Abort!"
        return 1
    fi

    # create user and group on demand
    if [ -z "$gid_c" ]; then
        log_info "Add EGO administration group \"$egoadmin_gname\" with gid \"$egoadmin_gid\"."
        $sudo groupadd -g $egoadmin_gid $egoadmin_gname

    fi && \
    if [ -z "$uid_c" ]; then
        log_info "Add EGO administration user \"$egoadmin_uname\" with gid \"$egoadmin_uid\"."
        $sudo useradd -g $egoadmin_gname -u $egoadmin_uid -c "EGO Administrator" $egoadmin_uname

    fi && { \
        fsudocfg=/etc/sudoers.d/$egoadmin_uname
        if ! $sudo test -f $fsudocfg; then
            log_info "Configure paswordless sudo for EGO administrator \"$egoadmin_uname\"."
            $sudo echo "Defaults:$egoadmin_uname !requiretty" >$fsudocfg
            $sudo echo "$egoadmin_uname ALL=(ALL) NOPASSWD:ALL" >>$fsudocfg
            $sudo chmod go-rwx $fsudocfg
        fi
    }

    # log for debug and passthrough return code
    local rc=$?
    if [ $rc -ne 0 ]; then
        log_error "Fail to create egoadmin user and group!"
    fi
    return $rc
}
function install_mn() {
    # invoke installer
    $sudo env \
        CLUSTERADMIN=$egoadmin_uname \
        BASEPORT=$BASEPORT \
        CLUSTERNAME=$CLUSTERNAME \
    bash $installerbin --quiet

    # shared commands
    local source_cmd="source $cwshome/profile.platform"
    local logon_cmd="egosh user logon -u Admin -x Admin"

    # join a ego cluster
    $sudo_const -u $egoadmin_uname bash -c "$source_cmd; egoconfig join $cwsmn -f"

    # set only when not entitled
    if ! $sudo bash -c "$source_cmd; $logon_cmd; ego entitlement info" | \
       grep -sq Entitled; then
        $sudo_const -u $egoadmin_uname bash -c "$source_cmd; egoconfig setentitlement $entitlement"
    fi

    # start ego
    $sudo bash -c "$source_cmd; egosh ego start"

    # view MN status
    sleep 2
    $sudo bash -c "$source_cmd; $logon_cmd; egosh resource list -l"

    # view web url for end user
    $sudo bash -c "$source_cmd; $logon_cmd; egosh client view GUIURL_1"
}
function install_cn() {
    # invoke installer
    $sudo env \
        CLUSTERADMIN=$egoadmin_uname \
        BASEPORT=$BASEPORT \
        CLUSTERNAME=$CLUSTERNAME \
        EGOCOMPUTEHOST=Y \
    bash $installerbin --quiet

    # shared commands
    local source_cmd="source $cwshome/profile.platform"
    local logon_cmd="egosh user logon -u Admin -x Admin"

    # join a ego cluster
    $sudo_const -u $egoadmin_uname bash -c "$source_cmd; egoconfig join $cwsmn -f"

    # start ego
    $sudo bash -c "$source_cmd; egosh ego start"

    # view MN status
    sleep 2
    $sudo bash -c "$source_cmd; $logon_cmd; egosh resource list -l"
}

if [ "$cwsrole" = "mn" -a "$cwsmn" = `hostname -s` ]; then
    create_egoadmin && \
    install_mn

elif [ "$cwsrole" = "cn" -a "$cwsmn" != `hostname -s` ]; then
    create_egoadmin && \
    install_cn
fi
