#! /usr/bin/env bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=0.1.0

# constant variables
lscm=lscm

rtc_repo=https://jazz07.rchland.ibm.com:21443/jazz/
rtc_user=fuzhiwen@cn.ibm.com
rtc_passwd_f=$HOME/.ssh/fuzhiwen@cn.ibm.com.rtc_passwd_f
rtc_stream=dlm_trunk
rtc_component=dlm

git_repo=git@github.ibm.com:platformcomputing/bluemind.git
git_branch=rtc-${rtc_stream}

source log.sh

workspace=$HOME/workspace
[ -d $workspace ] || mkdir -p $workspace

function rtc_login() {
    local lines=''
    for i in `seq 0 1`
    do
        lines=`$lscm list connections`
        if echo "$lines" | grep -F -sq "$rtc_repo, $rtc_user,"; then
            break

        elif [ $i -eq 0 ]; then
            $lscm login -r $rtc_repo -u $rtc_user --password-file $rtc_passwd_f
        fi
    done
    echo $i
}

rtc_login
