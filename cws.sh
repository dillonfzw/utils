#! /bin/bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=1.0.1


# constant variables
USER=${USER:-`whoami`}
HOSTNAME_S=${HOSTNAME_S:-`hostname -s`}
HOSTNAME_F=${HOSTNAME_F:-`hostname -f`}
PWD=${PWD:-`pwd`}

sudo_const="sudo -n -i"
if [ "$USER" != "root" ]; then
    sudo="$sudo_const"
fi


# default values of input parameters
DEFAULT_egoadmin_uname=egoadmin
t_uid=`id -u ${DEFAULT_egoadmin_uname}`
DEFAULT_egoadmin_uid=${t_uid:-320437}
DEFAULT_egoadmin_gname=egoadmin
t_gid=`id -g ${DEFAULT_egoadmin_uname}`
DEFAULT_egoadmin_gid=${t_gid:-537693}
DEFAULT_BASEPORT=17869
DEFAULT_CLUSTERNAME=cluster_dl_`hostname -s`
DEFAULT_installerbin=`ls -1at cws{,eval}-*.bin 2>/dev/null | head -n1`
DEFAULT_entitlement=`ls -1at $HOME/bin/entitlement-cws221* entitlement* 2>/dev/null | head -n1`
DEFAULT_cwshome=/opt/ibm/spectrumcomputing
DEFAULT_cwsrole=cn
DEFAULT_enforce=false
DEFAULT_cmd=""
if [ "$DEFAULT_cwsrole" = "mn" ]; then
    DEFAULT_cwsmn=$HOSTNAME_F
else
    DEFAULT_cwsmn=""
fi
unset t_uid t_gid


function listFunctions() {
    grep "^function " $PROGCLI | sed -e 's/^.*function *\(.*\)(.*$/\1/g'
}
function usage() {
    echo "Usage $PROGNAME"
    listFunctions | sed -e 's/^/[cmd] >> /g' | log_lines info
    exit 0
}

# import common libraries
source $PROGDIR/log.sh
source $PROGDIR/getopt.sh

[ -n "$cmd" ] || cmd="install_$cwsrole"

# shared commands
ego_source_cmd="source $cwshome/profile.platform"
ego_logon_cmd="egosh user logon -u Admin -x Admin"

function pstree() {
    pids="$@"
    pids_old=""
    while [ "$pids" != "$pids_old" ];
    do
        pids_old="$pids"
        pids=`ps --pid "$pids" --ppid "$pids" -o pid --no-headers | awk '{print $1}' | sort -u | xargs`
    done
    [ -n "$pids" ] && echo "$pids"
}
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
            echo "Defaults:$egoadmin_uname !requiretty" | $sudo tee $fsudocfg
            echo "$egoadmin_uname ALL=(ALL) NOPASSWD:ALL" | $sudo tee -a $fsudocfg
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
function wait_for_ego_up() {
    log_info "Wait EGO to be started up within 300 seconds"
    let i=1
    while [ $i -lt 300 ];
    do
        if ! $sudo bash -c "$ego_source_cmd; egosh ego info" 2>&1 | \
            grep -sq "Cannot contact the master host"; then
            break
        fi
        sleep 1
        ((i+=1))
    done
    test $i -lt 300
}
function wait_for_ego_down() {
    log_info "Wait EGO to be shutdown within 100 seconds"
    let i=1
    let cnt=100
    while [ $i -le $cnt ];
    do
        lines=`$sudo bash -c "$ego_source_cmd; egosh ego info" 2>&1`
        if echo "$lines" | grep -sq "Cannot contact the master"; then
            break
        fi
        ((i+=1))
        sleep 1
    done
    test $i -le $cnt
}
function enable_gpu() {
    let i=0
    while [ $i -lt 2 ];
    do
        if grep -sq -xF "EGO_GPU_ENABLED=Y" $cwshome/kernel/conf/ego.conf; then
            break
        elif [ $i -eq 0 ]; then
            log_info "Enable GPU monitoring feature..."
            # NOTE: following script is interactive!
            $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; `$ego_source_cmd; echo $EGO_TOP`/conductorspark/2.2.1/etc/gpuconfig.sh enable"
        elif [ $i -eq 1 ]; then
            log_error "Fail to enable GPU monitoring feature..."
        fi
        sleep 1
        ((i+=1))
    done
    test $i -lt 2
}
function start_cws() {
    # start ego
    $sudo bash -c "$ego_source_cmd; egosh ego start -f all"
    if ! wait_for_ego_up; then
        log_error "Cannot reach EGO master..."
        $sudo bash -c "$ego_source_cmd; ego ego info" 2>&1 | sed -e 's/^/>> /g' | log_lines error
        false
    fi
}
function wait_for_ego_services_down() {
    let i=1
    let interval_sleep=2
    let interval_disp=5
    let cnt=150
    while [ $i -le $cnt ];
    do
        lines=`$sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh service list" | \
               grep -vE " DEFINED |^SERVICE|Logged on successfully"`
        if [ -z "$lines" ]; then
            break
        elif [ $((i % interval_disp)) -eq 1 ]; then
            echo "$lines" | sed -e 's/^/>> /g' | log_lines debug
        fi

        log_debug "Wait $i/$cnt of sleep $interval_sleep interval..."
        sleep $interval_sleep
        ((i+=1))
    done
    test $i -le $cnt
}
function stop_cws() {
    # stop ego services
    if $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh service stop all"; then
        wait_for_ego_services_down
    else
        log_error "Fail to issue \"service stop all\" command to ego..."
        false
    fi && \
    # shutdown ego cluster
    if $sudo bash -c "$ego_source_cmd; egosh ego shutdown -f all"; then
        wait_for_ego_down
    else
        log_error "Fail to issue \"ego shutdown -f all\" command to ego..."
        false
    fi
}
function get_cws_pids() {
    lines=`ps -N --pid 2 -N --ppid 2 --no-headers -o pid,cmd`
    pids=`echo "$lines" | grep -w "$cwshome" | awk '{print $1}' | sort -u | xargs`
    pstree $pids
}
function kill_cws_pids() {
    let i=0
    # 0-1: term, 2-3: kill, 4: verify
    while [ $i -lt 5 ];
    do
        pids=`get_cws_pids`
        if [ -z "$pids" ]; then
            break
        elif [ $i -lt 2 ]; then
            ps -fH -o "$pids" | sed -e 's/^/>> [TERM_'$i']: /g' | log_lines info
            $sudo kill -TERM $pids
        elif [ $i -lt 4 ]; then
            ps -fH -o "$pids" | sed -e 's/^/>> [KILL_'$i']: /g' | log_lines info
            $sudo kill -KILL $pids
        fi
        sleep 1
        ((i+=1))
    done
    test $i -lt 5
}
function restart_cws() {
    stop_cws && \
    start_cws
}
function install_mn() {
    create_egoadmin || return 1

    if [ ! -f "$installerbin" ]; then
        log_error "Installer binary \"$installerbin\" does not exist."
        return 1
    fi
    if [ ! -f "$entitlement" ]; then
        log_error "Entitlement \"$entitlement\" does not exist."
        return 1
    fi

    # invoke installer
    $sudo env \
        CLUSTERADMIN=$egoadmin_uname \
        BASEPORT=$BASEPORT \
        CLUSTERNAME=$CLUSTERNAME \
    bash `readlink -m $installerbin` --quiet


    # join a ego cluster
    $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; egoconfig join $cwsmn -f"

    # set only when not entitled
    if ! $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh entitlement info" 2>&1 | \
       grep -sq Entitled; then
        log_info "Set entitlement with \"$entitlement\""
        $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; egoconfig setentitlement $entitlement"
    fi

    # start ego
    if start_cws; then
        # view MN status
        $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh resource list -l; egosh rg;"

        # view web url for end user
        $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh client view EGO_SERVICE_CONTROLLER"

        enable_gpu && \
        restart_cws
    else
        false
    fi
}
function install_cn() {
    create_egoadmin || return 1

    if [ ! -f "$installerbin" ]; then
        log_error "Installer binary \"$installerbin\" does not exist."
        return 1
    fi

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
    $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; egoconfig join $cwsmn -f"

    # start ego
    $sudo bash -c "$ego_source_cmd; egosh ego start"

    # view MN status
    if wait_for_ego_up; then
        $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh resource list -l"
    else
        log_error "Cannot reach EGO master..."
        $sudo bash -c "$ego_source_cmd; ego ego info" 2>&1 | sed -e 's/^/>> /g' | log_lines error
        false
    fi
}
function clean_cws_files() {
    if [ -n "$cwshome" -a -d "$cwshome" ]; then
        log_warn "Uninstall cws package enforcely"
        # egocore-3.6.0.1-439659.ppc64le
        # egowlp-17.0.0.1-439659.noarch
        # egomgmt-3.6.0.1-439659.noarch
        # egogpfsmonitor-3.6.0.1-439659.noarch
        # conductormgmt-2.2.1.0-439659.noarch
        # conductorsparkmgmt-2.2.1.0-439659.noarch
        # egojre-8.0.3.21-439659.ppc64le
        # egorest-3.6.0.1-439659.noarch
        # egoelastic-1.4.0.0-1.ppc64le
        # ascd-2.2.1.0-439659.noarch
        # conductorsparkcore-2.2.1.0-439659.ppc64le
        $sudo rpm -qa | grep -E "ego|conductor|ascd" | xargs $sudo rpm -e

        log_warn "Clean up CwS home directory \"$cwshome\".."
        $sudo_const -u $egoadmin_uname rm -rf $cwshome 2>/dev/null
        $sudo rm -i -rf $cwshome
    fi
}
function uninstall_cws_enforce() {
    kill_cws_pids && \
    clean_cws_files
}
function uninstall_cws() {
    if ! stop_cws && ! $enforce; then
        log_error "Stop CwS failed, use enforce=true to uninstall if you really knows what that means."
        return 1
    fi

    uninstaller=`ls -1 $cwshome/uninstall/*uninstall*.sh 2>/dev/null | head -n1`
    if [ -n "$uninstaller" ] && ! $sudo $uninstaller && ! $enforce; then
        log_error "Uninstall failed, use enforce=true to uninstall if you really knows what that means."
        return 1
    fi
    uninstall_cws_enforce
}
function dlpdOp() {
    act=${1:-start}

    # shared commands
    local source_cmd="source $cwshome/profile.platform"
    local logon_cmd="egosh user logon -u Admin -x Admin"

    $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; $logon_cmd; egosh service $act dlpd"
}
function restart_dlpd() {
    dlpdOp "instance restart -s"
}

# logic to valid input parameter
if [ `expr match "$cmd" "^install_"` -eq 8 -a "$cwsrole" = "cn" -a -z "$cwsmn" ]; then
    log_error "You must specify a valid CwS MN, \"cwsmn\", in order to install and setup a CwS CN" >&2
    exit 1
fi

if [ "$cmd" = "install_mn" -a "$cwsrole" = "mn" -a "$cwsmn" = "$HOSTNAME_F" ]; then
    install_mn $@

elif [ "$cmd" = "install_cn" -a "$cwsrole" = "cn" -a "$cwsmn" != "$HOSTNAME_F" ]; then
    install_cn $@

elif [ -n "$cmd" ]; then
    eval "$cmd $@"

else
    log_error "Invalid command line, no action had been taken."
fi
