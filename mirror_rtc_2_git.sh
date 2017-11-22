#! /usr/bin/env bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=0.1.0

##############################################
# Procedure to enable crontab for mirror tasks
#
# [fuzhiwen@kvm-007800 ~]$ crontab -e
# SHELL=/bin/bash
# MAILTO=fuzhiwen@cn.ibm.com
# CRON_TZ=Asia/Shanghai
# 
# 10 4,16 * * * for prj in dlm dlmfabric; do env DEFAULT_project=$prj /u/fuzhiwen/bin/mirror_rtc_2_git.sh; done

source $PROGDIR/log.sh

# constant variables
DEFAULT_lscm=lscm
DEFAULT_JAVA_HOME=${JAVA_HOME:-/opt/ibm/java-x86_64-80}

DEFAULT_rtc_repo=https://jazz07.rchland.ibm.com:21443/jazz/
DEFAULT_rtc_repo_alias=jazz
DEFAULT_rtc_user=fuzhiwen@cn.ibm.com
DEFAULT_rtc_passwd_f=$HOME/.ssh/fuzhiwen@cn.ibm.com.rtc_passwd_f

DEFAULT_project=${DEFAULT_project:-dlm_trunk}
DEFAULT_rtc_stream=$DEFAULT_project
if [ "$DEFAULT_project" = "dlm_trunk" ]; then
    DEFAULT_rtc_component=dlm
    DEFAULT_git_repo=git@github.ibm.com:fuzhiwen/bluemind.git

elif [ "$DEFAULT_project" = "dlm_tp0.4" ]; then
    DEFAULT_rtc_component=dlm
    DEFAULT_git_repo=git@github.ibm.com:fuzhiwen/bluemind.git

elif [ "$DEFAULT_project" = "dlm_1_1_0_Gold_Patch" ]; then
    DEFAULT_rtc_component=dlm
    DEFAULT_git_repo=git@github.ibm.com:fuzhiwen/bluemind.git
    DEFAULT_git_branch=rtc-dlm_r110

elif [ "$DEFAULT_project" = "dlmfabric_trunk" ]; then
    DEFAULT_rtc_component=dlmfabric
    DEFAULT_git_repo=git@github.ibm.com:sysongyu/fabric.git

elif [ "$DEFAULT_project" = "dlmfabric_tp0.4" ]; then
    DEFAULT_rtc_component=dlmfabric
    DEFAULT_git_repo=git@github.ibm.com:sysongyu/fabric.git

elif [ "$DEFAULT_project" = "dlmfabric_1_1_0_Gold_Patch" ]; then
    DEFAULT_rtc_component=dlmfabric
    DEFAULT_git_repo=git@github.ibm.com:sysongyu/fabric.git
    DEFAULT_git_branch=rtc-dlmfabric_r110

else
    log_error "Unknown project \"$DEFAULT_project\""
    exit 1
fi
DEFAULT_rtc_max_history=500
DEFAULT_rtc_workspace=m_${DEFAULT_rtc_stream}_`hostname -s`

DEFAULT_git_branch=${DEFAULT_git_branch:-rtc-${DEFAULT_rtc_stream}}
DEFAULT_git_user_email=fuzhiwen@cn.ibm.com
DEFAULT_git_user_name="Zhiwen Fu"
DEFAULT_sshKey="50:6b:02:cb:27:c6:3c:45:18:14:21:0a:22:ad:e2:59"

DEFAULT_fs_workspace=$HOME/rtc2git/${DEFAULT_rtc_workspace}

source $PROGDIR/getopt.sh

export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

rtc_root=$fs_workspace/.rtc_root
git_root=$fs_workspace/.git_root

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
    [ -d $rtc_root ] || mkdir -p $rtc_root
    if cd $rtc_root; then
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
            # need "-w" in case the line was too long and shrinked by lscm command
            lines=`$lscm status -w 2>&1`
            if echo "$lines" | grep -sq "Workspace: .* \"$rtc_workspace\" .* \"$rtc_stream\""; then
                { echo "$lines"; pwd; ls -la; } | sed -e 's/^/>> /g' | log_lines info
                break

            elif [ $i -eq 0 ]; then
                log_info "Load RTC component \"$rtc_component\" in workspace \"$rtc_workspace\" into directory \"$rtc_root\"..."
                lines=`$lscm load -r $rtc_repo --allow --force $rtc_workspace $rtc_component/ 2>&1`
                if [ $? -ne 0 ]; then echo "$lines" | sed -e 's/^/>> /g' | log_lines error; fi

            elif [ $i -eq 1 ]; then
                log_error "Fail to load RTC components \"$rtc_component\""
                echo "$lines" | sed -e 's/^/>> /g' | log_lines error
            fi
            ((i+=1))
        done
        test $i -lt 2
    else
        log_error "Fail to change directory to workspace in file system path \"$rtc_root\""
        false
    fi
}
function get_ssh_key() {
    let i=0
    while [ $i -lt 2 ];
    do
        if ssh-add -l | grep -wF -sq "$sshKey"; then
            break
        elif [ $i -eq 0 ]; then
            source attach_ssh-agent.sh
        elif [ $i -eq 1 ]; then
            log_error "Cannot find ssh key to github. Abort!"
        fi
        ((i+=1))
    done
    test $i -lt 2
}
function transfer_rtc_to_git() {
    # STEP_01: transfer rtc content to git local workspace
    if [ ! -d $git_root/$rtc_component ]; then
        mkdir -p $git_root/$rtc_component
    fi && \
    if cd $git_root/$rtc_component; then
        # initialize git
        if [ ! -d .git ]; then
            log_info "Clone git branch \"$git_branch\" at repo \"$git_repo\" into \"$git_root/$rtc_component\"..."
            git init && \
            git remote add origin $git_repo;
        else
            log_info "Fetch git branch \"$git_branch\" at repo \"$git_repo\" into \"$git_root/$rtc_component\"..."
        fi && \
        get_ssh_key && \
        # sync with git server
        git fetch origin +$git_branch:remotes/origin/$git_branch && \
        # update local copy
        if git branch | grep -sq '^\* \+'"$git_branch *$"; then
            lines=`git status`
            if ! echo "$lines" | grep -sq "working directory clean"; then
                log_warn "Working directory isn't clean. Let's do a hard reset..."
                echo "$lines" | sed -e 's/^/>> /g' | log_lines debug
                git reset --hard
            fi
            log_debug "Merge with up-stream branch \"$git_branch\""
            git merge origin/$git_branch | sed -e 's/^/>> /g' | log_lines debug
        else
            log_debug "Check out up-stream branch \"$git_branch\""
            git checkout $git_branch
        fi && {
            # transfer rtc code to git
            log_info "Transfer RTC code into git..."
            ls -a1 | grep -Exv "\.|\.\.|\.git" | xargs -I '{}' rm -rf {}
            tar -C $rtc_root -cf - $rtc_component | tar -C $git_root -xf -
            git status -s 2>&1 | sed -e 's/^/>> /g' | log_lines debug
        }

    else
        log_error "Fail to change directory to workspace in file system path \"$rtc_root\""
        false
    fi
}
function commit_code_in_git() {
    if cd $git_root/$rtc_component; then
        tmpf=`mktemp /tmp/XXXXXXXX`
        {
            echo "RTC import $rtc_stream (`timestamp -u`)"
            echo
            last_changeset=`git log -n1 | grep -A 1 "Change sets:" | sed -e 's/^ *\(.*\) *Added By: .*$/\1/g'`
            if cd $rtc_root/$rtc_component; then
                lines=`$lscm show history -w $rtc_workspace -C $rtc_component -m $rtc_max_history 2>&1`
                rc=$?
                if [ -n "$last_changeset" ]; then
                    lines_new=`echo "$lines" | grep -B9999 -F "${last_changeset}"`
                else
                    lines_new="$lines"
                fi
                echo "$lines_new"
                if [ $rc -ne 0 ]; then echo "$lines_new" | sed -e 's/^/>> /g' | log_lines error; false; fi
                cd - >/dev/null
                (exit $rc)
            fi
        } >$tmpf && {
            log_info "Commit code to git \"`head -n1 $tmpf`\""

            git add --all
            git config user.email $git_user_email
            git config user.name "$git_user_name"
            lines=`git commit -F $tmpf`
            echo "$lines" | sed -e 's/^/>> /g' | log_lines debug

            if ! echo "$lines" | grep -sq "nothing to commit"; then
                { git log -n2; } | sed -e 's/^/>> /g' | log_lines info

                log_info "Push code back to up-stream \"`head -n1 $tmpf`\""
                git push
            fi
            { git log --oneline -n10 --graph; } | sed -e 's/^/>> /g' | log_lines info
        }
        rm -f $tmpf

    else
        log_error "Fail to change directory to workspace in file system path \"$git_root\""
        false
    fi
}
function unload_rtc_workspace() {
    log_info "Unload RTC workspace \"$rtc_workspace\"..."
    if cd $rtc_root; then
        lines=`$lscm unload -r $rtc_repo -w $rtc_workspace -C $rtc_component 2>&1`
        rc=$?
        if [ $rc -ne 0 ]; then echo "$lines" | sed -e 's/^/>> /g' | log_lines error; false; fi
        cd - >/dev/null
        (exit $rc)
    fi
}
function delete_rtc_workspace() {
    log_info "Delete RTC workspace \"$rtc_workspace\"..."
    if cd $rtc_root; then
        lines=`$lscm delete workspace -r $rtc_repo $rtc_workspace 2>&1`
        rc=$?
        if [ $rc -ne 0 ]; then echo "$lines" | sed -e 's/^/>> /g' | log_lines error; false; fi
        cd - >/dev/null
        (exit $rc)
    fi
}

echo "

+-----------------------------------------------------------
| Mirror project \"$project\" from RTC to git
|
| RTC_stream:    \"$rtc_stream\"
| RTC_component: \"$rtc_component\"
+-----------------------------------------------------------

" | log_lines info

rtc_login && \
create_rtc_workspace && \
load_rtc_workspace && \
transfer_rtc_to_git && \
commit_code_in_git && \
unload_rtc_workspace && \
delete_rtc_workspace

if [ -n "$rtc_root" -a -n "$rtc_component" ]; then
    rm -rf $rtc_root/{$rtc_component, .jazz*}
fi
