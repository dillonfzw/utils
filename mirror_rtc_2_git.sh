#! /usr/bin/env bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=0.1.0

# constant variables
DEFAULT_lscm=lscm
DEFAULT_JAVA_HOME=${JAVA_HOME:-/opt/ibm/java-x86_64-80}

DEFAULT_rtc_repo=https://jazz07.rchland.ibm.com:21443/jazz/
DEFAULT_rtc_repo_alias=jazz
DEFAULT_rtc_user=fuzhiwen@cn.ibm.com
DEFAULT_rtc_passwd_f=$HOME/.ssh/fuzhiwen@cn.ibm.com.rtc_passwd_f
DEFAULT_rtc_stream=dlm_trunk
DEFAULT_rtc_component=dlm
DEFAULT_rtc_workspace=m_${DEFAULT_rtc_stream}_`hostname -s`

DEFAULT_git_repo=git@github.ibm.com:platformcomputing/bluemind.git
DEFAULT_git_branch=rtc-${DEFAULT_rtc_stream}
DEFAULT_fs_workspace=$HOME/workspace/tmp
DEFAULT_git_user_email=fuzhiwen@cn.ibm.com
DEFAULT_git_user_name="Zhiwen Fu"

source $PROGDIR/log.sh
source $PROGDIR/getopt.sh

export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

# RTC import dlm_trunk (13-Jun-2017 04:29 AM)
function timestamp() {
    local args=$@
    date $args '+%Y%m%d_%H%M'
}
function rtc_login() {
    local lines=''
    local i=0
    while [ $i -lt 2 ];
    do
        lines=`$lscm list connections`
        if echo "$lines" | grep -F -sq "$rtc_repo, $rtc_user,"; then
            echo "$lines" | sed -e 's/^/>> /g' | log_lines info
            break

        elif [ $i -eq 0 ]; then
            log_info "Login RTC repo \"$rtc_repo\" with user \"$rtc_user\"..."
            lines=`$lscm login -r $rtc_repo -u $rtc_user --password-file $rtc_passwd_f -n $rtc_repo_alias 2>&1`
            if [ $? -ne 0 ]; then echo "$lines" | sed -e 's/^/>> /g' | log_lines error; fi
        fi
        ((i+=1))
    done
    test $i -lt 2
}
function create_rtc_workspace() {
    local i=0
    while [ $i -lt 2 ];
    do
        lines=`$lscm list workspace -r $rtc_repo -n "$rtc_workspace"`
        if echo "$lines" | grep -F -sq "$rtc_workspace"; then
            echo "$lines" | sed -e 's/^/>> /g' | log_lines info
            break

        elif [ $i -eq 0 ]; then
            log_info "Create RTC workspace \"$rtc_workspace\"..."
            lines=`$lscm create workspace -r $rtc_repo --stream $rtc_stream $rtc_workspace 2>&1`
            if [ $? -ne 0 ]; then echo "$lines" | sed -e 's/^/>> /g' | log_lines error; fi
        fi
        ((i+=1))
    done
    test $i -lt 2
}
function load_rtc_workspace() {
    [ -d $fs_workspace ] || mkdir -p $fs_workspace
    if cd $fs_workspace; then
        # [fuzhiwen@kvm-007800 tmp]$ lscm status
        # Workspace: (1031) "m_dlm_trunk_kvm-007800" <-> (1012) "dlm_trunk"
        #   Component: (1032) "dlm"
        #     Baseline: (1033) 6 "Daily_dlm_trunk_Jun_12_2017_04:00"
        #     Incoming: 
        #       Change sets:
        #         (1034) ----$ QING LI 153833 "[Inference-Validation] After training is...
        local i=0
        while [ $i -lt 2 ];
        do
            #log_info "Check RTC status at current directory \"`pwd`\" in round $i..."
            lines=`$lscm status 2>&1`
            if echo "$lines" | grep -sq "Workspace: .* \"$rtc_workspace\" .* \"$rtc_stream\""; then
                { echo "$lines"; pwd; ls -la; } | sed -e 's/^/>> /g' | log_lines info
                break
            elif [ $i -eq 0 ]; then
                log_info "Load RTC component \"$rtc_component\" in workspace \"$rtc_workspace\" into directory \"$fs_workspace\"..."
                lines=`$lscm load -r $rtc_repo --allow --force $rtc_workspace $rtc_component/ 2>&1`
                if [ $? -ne 0 ]; then echo "$lines" | sed -e 's/^/>> /g' | log_lines error; fi
            fi
            ((i+=1))
        done
        test $i -lt 2
    else
        log_error "Fail to change directory to workspace in file system path \"$fs_workspace\""
        false
    fi
}
function transfer_rtc_to_git() {
    [ -d $fs_workspace ] || mkdir -p $fs_workspace
    if cd $fs_workspace/$rtc_component; then
        # stage rtc content
        tmpd=`mktemp -d .XXXXXXXX`
        ls -a1 | grep -Exv ".|..|.git|$tmpd" | xargs -I '{}' mv {} $tmpd/

        # initialize git
        if [ ! -d .git ]; then
            git init && \
            git remote add origin $git_repo;
        fi && \
        git fetch origin +$git_branch:remotes/origin/$git_branch && \
        git checkout $git_branch

        # transfer rtc code to git
        ls -a1 | grep -Exv ".|..|.git|$tmpd" | xargs -I '{}' rm -rf {}
        if cd $tmpd; then
            ls -a1 | grep -Exv ".|.." | xargs -I '{}' mv {} ../; 
            cd - >/dev/null
            rmdir $tmpd
        fi

        git status -s 2>&1 | sed -e 's/^/>> /g' | log_lines debug

    else
        log_error "Fail to change directory to workspace in file system path \"$fs_workspace\""
        false
    fi
}
function commit_code_in_git() {
    if cd $fs_workspace/$rtc_component; then
        tmpf=`mktemp /tmp/XXXXXXXX`
        {
            echo "RTC import dlm_trunk (`timestamp -u`)"
            echo
            $lscm show history 2>&1
        } >$tmpf
        git add --all
        git config user.email $git_user_email
        git config user.name "$git_user_name"
        git commit -F $tmpf && rm -f $tmpf

        git log -n2 | sed -e 's/^/>> /g' | log_lines info
        git push
    else
        log_error "Fail to change directory to workspace in file system path \"$fs_workspace\""
        false
    fi
}
function unload_rtc_workspace() {
    log_info "Unload RTC workspace \"$rtc_workspace\"..."
    $lscm unload -r $rtc_repo $rtc_workspace
}
function delete_rtc_workspace() {
    log_info "Delete RTC workspace \"$rtc_workspace\"..."
    $lscm delete workspace -r $rtc_repo $rtc_workspace
}

rtc_login && \
create_rtc_workspace && \
load_rtc_workspace && \
transfer_rtc_to_git && \
commit_code_in_git && \
unload_rtc_workspace && \
delete_rtc_workspace

rm -rf $fs_workspace
