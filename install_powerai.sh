#! /bin/bash

# Copyright 2017 IBM Corp.
#
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#               ------------------------------------------
#               THIS SCRIPT PROVIDED AS IS WITHOUT SUPPORT
#               ------------------------------------------

[ "$DEBUG" = "true" ] && set -x

##################################
# load base library
#
declare log_sh=log.sh
declare log_sh_path=${cache_dir:-$HOME/.cache}/utils/$log_sh
declare log_sh_url=https://github.com/dillonfzw/utils/raw/master/$log_sh
if command -v $log_sh >/dev/null; then
    source $log_sh

else
    [ ! -f $log_sh_path ] && mkdir -p `dirname $log_sh_path` && \
    curl -SL -m 60 $log_sh_url -o $log_sh_path
    [ -f $log_sh_path ] && source $log_sh_path
fi
if ! declare -F log_lines >/dev/null; then
    echo "[W]: Fail to load \"log.sh\" library. Abort!" >&2
    exit 1
    false && \
    for item in error warn info debug
    do
        p=`expr substr $item 1 1 | tr [a-z] [A-Z]`
        eval "function log_$item { echo \"[$p]: \$@\" >&2; }"
    done
fi

#########################
# common constant variables
USER=`whoami`
# add prefix "sudo" if NOT root
if [ "$USER" = "root" ]; then sudo=""; else sudo=sudo; fi

eval "OS_ID=`grep "^ID=" /etc/os-release | cut -d= -f2-`"
eval "OS_VER=`grep "^VERSION_ID=" /etc/os-release | cut -d= -f2-`"
if [ "$OS_ID" = "rhel" ]; then
    is_rhel=true; is_ubuntu=false;
else
    is_rhel=false; is_ubuntu=true;
fi

#############################
# app related variables
#
# refer to official web link:
# https://ibm.biz/powerai
# https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/README.html
r4_repo_url="https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/mldl-repo-network_4.0.0_ppc64el.deb"
nvidia_repo_baseurl=ftp://bejgsa.ibm.com/gsa/home/f/u/fuzhiwen/Public/nvidia

cache_dir=$HOME/.cache/powerai
cache_dir_download=$cache_dir/download


function download_and_install() {
    url=$1
    f=`basename $url`
    [ -d $cache_dir_download ] || mkdir -p $cache_dir_download

    if [ ! -f $cache_dir_download/$f ]; then
        if cd $cache_dir_download; then
            log_info "Download and cache \"$f\" from url \"$url\""

            curl -SL $url -O
            rc=$?
            cd -
            (exit $rc)
        fi
    fi
    if [ -f $cache_dir_download/$f ]; then
        $sudo dpkg -i $cache_dir_download/$f
    else
        log_error "Fail to download and install \"$url\""
    fi
}
function print_title() {
    echo -e "\n"
    echo "+-----------------------------------------------------------"
    echo "| $@"
    echo "+-----------------------------------------------------------"
    echo -e "\n"
}
function install_nvidia() {
    print_title "Install nvidia-dirver" | log_lines info && \
    download_and_install $nvidia_repo_baseurl/nvidia-driver-local-repo-ubuntu1604-384.59_1.0-1_ppc64el.deb && \

    print_title "Install cuda-repo" | log_lines info && \
    download_and_install $nvidia_repo_baseurl/cuda-repo-ubuntu1604-8-0-local-ga2v2_8.0.61-1_ppc64el.deb && \

    print_title "Upgrade OS" | log_lines info && \
    $sudo apt-get update && \
    $sudo apt-get install -y unattended-upgrades && \
    $sudo unattended-upgrades -v && \

    print_title "Install cuda-drivers" | log_lines info && \
    $sudo apt-get install -y cuda-drivers &&

    print_title "Install cudnn6" | log_lines info && \
    download_and_install $nvidia_repo_baseurl/libcudnn6_6.0.20-1+cuda8.0_ppc64el.deb && \
    download_and_install $nvidia_repo_baseurl/libcudnn6-dev_6.0.20-1+cuda8.0_ppc64el.deb && \
    download_and_install $nvidia_repo_baseurl/libcudnn6-doc_6.0.20-1+cuda8.0_ppc64el.deb
}
function install_powerai() {
    print_title "Install mldl-repo" | log_lines info && \
    download_and_install $r4_repo_url && \

    print_title "Install power-mldl" | log_lines info && \
    $sudo apt-get update && \
    $sudo apt-get install -y power-mldl
}

if [ `expr match "$1" "^cmd="` -eq 4 ]; then
    cmd=`echo "$1" | cut -d= -f2`
    $cmd $@
    exit $?
fi

install_nvidia && \
install_powerai
