#! /usr/bin/env bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=0.1.0

# constant variables
DEFAULT_lscm=lscm
DEFAULT_JAVA_HOME=${JAVA_HOME:-/opt/ibm/java-x86_64-80}

DEFAULT_rtc_repo=https://jazz07.rchland.ibm.com:21443/jazz/
DEFAULT_rtc_user=fuzhiwen@cn.ibm.com
DEFAULT_rtc_passwd_f=$HOME/.ssh/fuzhiwen@cn.ibm.com.rtc_passwd_f
DEFAULT_rtc_stream=dlm_trunk
DEFAULT_rtc_component=dlm

DEFAULT_git_repo=git@github.ibm.com:platformcomputing/bluemind.git
DEFAULT_git_branch=rtc-${rtc_stream}
DEFAULT_workspace=$HOME/workspace

source $PROGDIR/log.sh
source $PROGDIR/getopt.sh

[ -d $workspace ] || mkdir -p $workspace
export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

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
            lines=`$lscm login -r $rtc_repo -u $rtc_user --password-file $rtc_passwd_f 2>&1`
            if [ $? -ne 0 ]; then
                echo "$lines" | sed -e 's/^/>> /g' | log_lines error
            fi
        fi
        ((i+=1))
    done
    test $i -lt 2
}

rtc_login
