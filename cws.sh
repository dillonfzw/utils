#! /bin/bash

if [ "$DEBUG" = "true" ]; then set -x; fi

PROGCLI=`command -v $0`
PROGNAME=${PROGCLI##*/}
PROGDIR=${PROGCLI%/*}
PROGVERSION=1.0.1


# constant variables
ARCH=${ARCH:-`uname -m`}
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
DEFAULT_installerbin=`ls -1at cws{,eval}-*${ARCH}.bin 2>/dev/null | head -n1`
DEFAULT_installerbin_dli=${DEFAULT_installerbin_dli:-`ls -1at dli-*${ARCH}.bin 2>/dev/null | sort -V | tail -n1`}
DEFAULT_entitlement=`ls -1at $HOME/bin/entitlement-cws221* entitlement* 2>/dev/null | head -n1`
DEFAULT_cwshome=/opt/ibm/spectrumcomputing
DEFAULT_cwsrole=cn
DEFAULT_enforce=false
DEFAULT_cmd=""
DEFAULT_DLI_SHARED_FS=/gpfs/dlfs1/$HOSTNAME_S
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

if [ -z "$cmd" ]; then
    cmd="install_$cwsrole"
    log_info "Default variable \"cmd\" to \"$cmd\""
fi

# shared commands
ego_source_cmd="source $cwshome/profile.platform"
ego_logon_cmd="egosh user logon -u Admin -x Admin"

function getUserShell() {
    local in_user=${1:-$egoadmin_uname}
    $sudo_const -u $in_user -i echo '$SHELL'
}
function checkAndFixDashIssue() {
    if getUserShell | grep -sq -w dash; then
        if $enforce; then
            log_info "Replace egoadmin user \"$egoadmin_uname\" shell from \"dash\" to \"bash\""
            $sudo usermod -s `command -v bash` $egoadmin_uname
        else
            log_error "egoadmin user \"$egoadmin_uname\" shell should NOT be \"dash\""
            false
        fi
    fi
}
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
        $sudo useradd -g $egoadmin_gname -u $egoadmin_uid -c "EGO Administrator" -s `command -v bash` $egoadmin_uname

    fi && \

    checkAndFixDashIssue && \

    # config password less sudo
    {
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
function egoServiceOp() {
    #$sudo_const -u $egoadmin_uname \
    eval "bash -c '$ego_source_cmd; $ego_logon_cmd; egosh service $@'"
}
function wait_for_ego_up() {
    log_info "Wait EGO to be started up within 300 seconds"
    local i=1
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
    local interval=1
    local cnt=100
    log_info "Wait EGO to be shutdown within $((interval * cnt)) seconds"
    local i=1
    while [ $i -le $cnt ];
    do
        lines=`$sudo bash -c "$ego_source_cmd; egosh ego info" 2>&1`
        if echo "$lines" | grep -sq "Cannot contact the master"; then
            break
        fi
        ((i+=1))
        sleep $interval
    done
    test $i -le $cnt
}
function enable_gpu() {
    local i=0
    while [ $i -lt 2 ];
    do
        if grep -sq -xF "EGO_GPU_ENABLED=Y" $cwshome/kernel/conf/ego.conf; then
            break
        elif [ $i -eq 0 ]; then
            log_info "Enable GPU monitoring feature..."
            # NOTE: following script is interactive!
            echo '
set timeout 20
spawn '"$sudo bash -c \"$ego_source_cmd; $ego_logon_cmd; `$ego_source_cmd; echo $EGO_TOP`/conductorspark/2.2.1/etc/gpuconfig.sh enable\""'
expect "user account:" { send "Admin\r"; }
expect "password:" { send "Admin\r"; }
expect "Do you want to continue?(Y/N)" { send "Y\r"; }
expect "Do you want to restart cluster now?(Y/N)" { send "Y\r"; }
expect "Do you really want to restart LIMs on all hosts? *y/n]" { send "y\r"; }
interact' | expect -f -
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
    local i=1
    local interval_sleep=2
    local interval_disp=5
    local cnt=150

    log_info "Wait until all ego services were shutdown in $((cnt * interval_sleep)) seconds."
    while [ $i -le $cnt ];
    do
        lines=`egoServiceOp list | \
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
    if egoServiceOp stop all; then
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
    [ -n "$pids" ] && pstree $pids
}
function kill_cws_pids() {
    local i=0
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
function install_dli() {
    if [ "$cwsmn" != "$HOSTNAME_F" ]; then
        log_error "DLI only needs to be uninstalled in MN"
        false

    elif [ -z "$DLI_SHARED_FS" -o ! -d "$DLI_SHARED_FS" ]; then
        log_error "DLI_SHARED_FS \"$DLI_SHARED_FS\" does not exists!"
        false

    fi && \

    # invoke installer
    # source ego profile is not mandatory. but just in case there are bug in the rpm installer
    # which might depends on those EGO related settings.
    if ! $sudo bash -c "$ego_source_cmd; env \
        CLUSTERADMIN=$egoadmin_uname \
        DLI_SHARED_FS=$DLI_SHARED_FS \
        ${CAFFE_HOME:+"CAFFE_HOME=$CAFFE_HOME"} \
        bash `readlink -m $installerbin_dli` --prefix=$cwshome --quiet"; then

        log_error "Fail to install DLI"
        false
    fi && \

    restart_cws
}
function uninstall_dli() {
    local uninstaller=$cwshome/dli/uninstall/cws_dl_uninstall.sh

    if ! $sudo $uninstaller && ! $enforce; then
        log_error "Fail to uninstall DLI"
        false
    fi && \
    if $enforce; then
        log_warn "Uninstall dli rpm package enforcely"
        $sudo rpm -qa | grep -E "^dli" | xargs $sudo rpm -e

        log_warn "Clean dli directory"
        $sudo rm -rf $cwshome/dli
    fi
}
function setup_os() {
    local f=/etc/sysctl.d/cws.conf
    if ! $sudo test -f $f; then
        local val=`{ sysctl vm.max_map_count | awk '{print $3}'; echo "262144"; } | sort -n | tail -n1`
        echo "vm.max_map_count=$val" | $sudo tee $f
    fi && \
    $sudo sysctl --load $f
}
function install_mn() {
    if [ ! -f "$installerbin" ]; then
        log_error "CwS installer binary \"$installerbin\" does not exist."
        false

    elif [ -n "$installerbin_dli" -a ! -f "$installerbin_dli" ]; then
        log_error "DLI installer binary \"$installerbin_dli\" does not exist."
        false

    elif [ ! -f "$entitlement" ]; then
        log_error "Entitlement \"$entitlement\" does not exist."
        false

    elif ! grep -sq "^conductor_deep_learning" $entitlement; then
        log_error "DLI Entitlement does not provided in entitlement \"$entitlement\""
        false

    elif [ -z "$cwsmn" ]; then
        log_error "cwsmn should not be empty!"
        false

    fi && \

    create_egoadmin && \
    setup_os && \

    # invoke installer
    if ! $sudo env \
        CLUSTERADMIN=$egoadmin_uname \
        BASEPORT=$BASEPORT \
        CLUSTERNAME=$CLUSTERNAME \
        bash `readlink -m $installerbin` --quiet; then

        log_error "Fail to install CWS in MN"
        false
    fi && \

    # join a ego cluster
    $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; egoconfig join $cwsmn -f" && \

    # set only when not entitled, or enforced.
    if $enforce || \
       ! $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh entitlement info" 2>&1 | \
       grep -sq Entitled; then

        log_info "Set entitlement with \"$entitlement\""
        $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; egoconfig setentitlement `readlink -m $entitlement`"
    fi && \

    # start ego
    if start_cws; then
        # view MN status
        $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh resource list -l; egosh rg;" && \

        # view web url for end user
        $sudo bash -c "$ego_source_cmd; $ego_logon_cmd; egosh client view EGO_SERVICE_CONTROLLER" && \

        enable_gpu
    else
        false
    fi && \

    # install DLI
    if [ -n "$installerbin_dli" ]; then
        install_dli
    fi && \

    # final cws restart
    restart_cws
}
function install_cn() {
    if [ ! -f "$installerbin" ]; then
        log_error "Installer binary \"$installerbin\" does not exist."
        false

    elif [ -z "$cwsmn" ]; then
        log_error "cwsmn should not be empty!"
        false

    fi && \

    create_egoadmin && \

    # invoke installer
    if ! $sudo env \
        CLUSTERADMIN=$egoadmin_uname \
        BASEPORT=$BASEPORT \
        CLUSTERNAME=$CLUSTERNAME \
        EGOCOMPUTEHOST=Y \
        bash `readlink -m $installerbin` --quiet; then

        log_error "Fail to install CwS in CN"
        false
    fi && \

    # join a ego cluster
    $sudo_const -u $egoadmin_uname bash -c "$ego_source_cmd; egoconfig join $cwsmn -f" && \

    # start ego
    $sudo bash -c "$ego_source_cmd; egosh ego start" && \

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
        # dli{core,mgmt}
        $sudo rpm -qa | grep -E "ego|conductor|ascd|dli" | xargs $sudo rpm -e

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
    uninstall_dli && \

    if ! stop_cws && ! $enforce; then
        log_error "Stop CwS failed, use enforce=true to uninstall if you really knows what that means."
        false
    fi && \

    {
        uninstaller=`ls -1 $cwshome/uninstall/*uninstall*.sh 2>/dev/null | head -n1`
        function auto_cws_uninstall() {
            echo '
set timeout 20
spawn '"$sudo $uninstaller"'
expect "Please input Y or N:" { send "Y\r"; }
interact
' | expect -f -
        }
        if [ -n "$uninstaller" ] && ! $auto_cws_uninstaller && ! $enforce; then
            log_error "Uninstall failed, use enforce=true to uninstall if you really knows what that means."
            false
        fi && \
        uninstall_cws_enforce
    }
}
function restart_dlpd() {
    seqid=${1:-1}
    egoServiceOp "instance restart -s dlpd $seqid"
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
