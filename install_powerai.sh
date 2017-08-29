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

#########################
# common constant variables
USER=`whoami`
# add prefix "sudo" if NOT root
flags=${DEBIAN_FRONTEND:+DEBIAN_FRONTEND=}$DEBIAN_FRONTEND
if [ "$USER" = "root" ]; then sudo=""; else sudo="sudo $flags"; fi

eval "OS_ID=`grep "^ID=" /etc/os-release | cut -d= -f2-`"
eval "OS_VER=`grep "^VERSION_ID=" /etc/os-release | cut -d= -f2-`"
if [ "$OS_ID" = "rhel" ]; then
    is_rhel=true; is_ubuntu=false;
else
    is_rhel=false; is_ubuntu=true;
fi

#######################################
# top level pre-requests to run the scripts
apt_get_install_options=${apt_get_install_options}${apt_get_install_options:+ }"-y"
apt_get_install_options=${apt_get_install_options}${apt_get_install_options:+ }"--allow-unauthenticated"
apt_get_install_options=${apt_get_install_options}${apt_get_install_options:+ }"--no-install-recommends"
# NOTE: support running w/o tty to avoid unexpected hang when running pkg configurating script
# this is required when running this script in docker build environment
if tty -s; then
    apt_get="apt-get"
else
    apt_get="env DEBIAN_FRONTEND=noninteractive apt-get"
fi

# - curl is required to smartly retrieve other dependencies
if ! command -v curl >/dev/null; then
    pkgs=${pkgs}${pkgs:+ }"curl"
fi
# - apt-transport-https is to prevent apt repo hash mismatch issue caused by
#   internet cache. A workaround was to use https:// apt source
if [ ! -f /usr/lib/apt/methods/https ]; then
    pkgs=${pkgs}${pkgs:+ }"apt-transport-https ca-certificates openssl"
fi
if [ -n "$pkgs" ]; then
    $sudo $apt_get update && \
    $sudo $apt_get install $apt_get_install_options $pkgs
fi || {
    echo "Fail to install dependency libs. Abort!"
    exit 1
}

##################################
# load base library smartly
#
declare log_sh=log.sh
declare log_sh_path=${cache_home:-$HOME/.cache}/utils/$log_sh
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

#############################
# app related variables
#
# refer to official web link:
# https://ibm.biz/powerai
# https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/README.html
CUDA_VERSION=${CUDA_VERSION:-8.0}
CUDA_PKG_VERSION=`echo $CUDA_VERSION | tr '.' '-'`

DEFAULT_r4_repo_url="https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/mldl-repo-network_4.0.0_ppc64el.deb"
DEFAULT_nvidia_repo_src=online
DEFAULT_nvidia_repo_baseurl="ftp://bejgsa.ibm.com/gsa/home/f/u/fuzhiwen/Public/nvidia"
DEFAULT_nvidia_driver_fname="nvidia-driver-local-repo-ubuntu1604-384.59_1.0-1_ppc64el.deb"
DEFAULT_cuda_repo_fname="cuda-repo-ubuntu1604-8-0-local-ga2v2_8.0.61-1_ppc64el.deb"
DEFAULT_cudnn_fnames=${DEFAULT_cudnn_fnames}${DEFAULT_cudnn_fnames:+ }"libcudnn6_6.0.20-1+cuda8.0_ppc64el.deb"
DEFAULT_cudnn_fnames=${DEFAULT_cudnn_fnames}${DEFAULT_cudnn_fnames:+ }"libcudnn6-dev_6.0.20-1+cuda8.0_ppc64el.deb"
DEFAULT_cudnn_fnames=${DEFAULT_cudnn_fnames}${DEFAULT_cudnn_fnames:+ }"libcudnn6-doc_6.0.20-1+cuda8.0_ppc64el.deb"
DEFAULT_cache_home=$HOME/.cache
DEFAULT_need_nvidia_driver=false

r4_repo_url=${r4_repo_url:-$DEFAULT_r4_repo_url}
nvidia_repo_src=${nvidia_repo_src:-$DEFAULT_nvidia_repo_src}
nvidia_repo_baseurl=${nvidia_repo_baseurl:-$DEFAULT_nvidia_repo_baseurl}
nvidia_driver_fname=${nvidia_driver_fname:-$DEFAULT_nvidia_driver_fname}
cuda_repo_fname=${cuda_repo_fname:-$DEFAULT_cuda_repo_fname}
cudnn_fnames=${cudnn_fnames:-$DEFAULT_cudnn_fnames}

# Cache directory is used to cache the content which downloaded remotely.
# For example: nvidia cuda, cudnn, driver pkgs in offline mode and powerai pkgs
cache_home=${cache_home:-$DEFAULT_cache_home}
cache_powerai_download=${cache_powerai_download:-$cache_home/powerai/download}

# NOTE:
# nvidia driver is not required in development only environment, such as a docker container
# It only required by runtime environment.
need_nvidia_driver=${need_nvidia_driver:-$DEFAULT_need_nvidia_driver}

#########################################
# Utility functions
function download_and_install() {
    url=$1
    f=`basename $url`
    [ -d $cache_powerai_download ] || mkdir -p $cache_powerai_download

    if [ ! -f $cache_powerai_download/$f ]; then
        if cd $cache_powerai_download; then
            log_info "Download and cache \"$f\" from url \"$url\""

            curl -SL $url -O
            rc=$?
            cd -
            (exit $rc)
        fi
    fi && \
    if [ -f $cache_powerai_download/$f ]; then
        $sudo dpkg -i $cache_powerai_download/$f
    else
        log_error "Fail to download and install \"$url\""
        false
    fi
}
function print_title() {
    echo -e "\n"
    echo "+-----------------------------------------------------------"
    echo "| $@"
    echo "+-----------------------------------------------------------"
    echo -e "\n"
}
# end of utility functions
#########################################

function install_cuda_pkgs() {
    print_title "Install $1 cuda runtime pkgs" | log_lines info && {
        $sudo $apt_get install $apt_get_install_options \
            cuda-nvrtc-$CUDA_PKG_VERSION \
            cuda-nvgraph-$CUDA_PKG_VERSION \
            cuda-cusolver-$CUDA_PKG_VERSION \
            cuda-cublas-$CUDA_PKG_VERSION \
            cuda-cufft-$CUDA_PKG_VERSION \
            cuda-curand-$CUDA_PKG_VERSION \
            cuda-cusparse-$CUDA_PKG_VERSION \
            cuda-npp-$CUDA_PKG_VERSION \
            cuda-cudart-$CUDA_PKG_VERSION && \
        if [ ! -d /usr/local/cuda ]; then
            $sudo ln -s cuda-$CUDA_VERSION /usr/local/cuda
        fi && \
        f=/etc/ld.so.conf.d/cuda.conf && if [ ! -f $f ]; then
            echo "/usr/local/cuda/lib" | $sudo tee -a $f
            echo "/usr/local/cuda/lib64" | $sudo tee -a $f
        fi && \
        f=/etc/ld.so.conf.d/nvidia.conf && if [ ! -f $f ]; then
            echo "/usr/local/nvidia/lib" | $sudo tee -a $f
            echo "/usr/local/nvidia/lib64" | $sudo tee -a $f
        fi
    } && \

    print_title "Install $1 cuda development pkgs" | log_lines info && {
        $sudo $apt_get install $apt_get_install_options \
            cuda-core-$CUDA_PKG_VERSION \
            cuda-misc-headers-$CUDA_PKG_VERSION \
            cuda-command-line-tools-$CUDA_PKG_VERSION \
            cuda-nvrtc-dev-$CUDA_PKG_VERSION \
            cuda-nvml-dev-$CUDA_PKG_VERSION \
            cuda-nvgraph-dev-$CUDA_PKG_VERSION \
            cuda-cusolver-dev-$CUDA_PKG_VERSION \
            cuda-cublas-dev-$CUDA_PKG_VERSION \
            cuda-cufft-dev-$CUDA_PKG_VERSION \
            cuda-curand-dev-$CUDA_PKG_VERSION \
            cuda-cusparse-dev-$CUDA_PKG_VERSION \
            cuda-npp-dev-$CUDA_PKG_VERSION \
            cuda-cudart-dev-$CUDA_PKG_VERSION \
            cuda-driver-dev-$CUDA_PKG_VERSION
    }
}
function install_cudnn6_tar() {
    print_title "Install cudnn online" | log_lines info && {
        # https://github.com/dillonfzw/nvidia-docker/blob/ppc64le/ubuntu-16.04/cuda/8.0/devel/cudnn6/Dockerfile.ppc64le
        CUDNN_DOWNLOAD_SUM=bb32b7eb8bd1edfd63b39fb8239bba2e9b4d0b3b262043a5c6b41fa1ea1c1472 && \
        URL=http://developer.download.nvidia.com/compute/redist/cudnn/v6.0/cudnn-8.0-linux-ppc64le-v6.0.tgz && \
            curl -fSL $URL -O && \
        FILE=${URL##*/} && \
            echo "$CUDNN_DOWNLOAD_SUM  $FILE" | sha256sum -c --strict - && \
            $sudo tar -xzf $FILE -C /usr/local && \
            rm $FILE && \
        $sudo ldconfig
    }
}
function install_cudnn6_deb() {
    print_title "Install offline cudnn" | log_lines info && {
        let scnt_max=`echo "$cudnn_fnames" | awk -F'[, ]' '{print NF}'`
        let scnt=0
        for FILE in $cudnn_fnames
        do
            if download_and_install $nvidia_repo_baseurl/$FILE; then ((scnt+=1)); else break; fi
        done
        test $scnt -eq $scnt_max
    }
}
function install_cuda_online() {
    print_title "Install online cuda repo" | log_lines info && \
    if [ ! -f /etc/apt/sources.list.d/cuda.list ]; then
        # https://github.com/dillonfzw/nvidia-docker/blob/ppc64le/ubuntu-16.04/cuda/8.0/runtime/Dockerfile.ppc64le
        NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
        NVIDIA_GPGKEY_FPR=ae09fe4bbd223a84b2ccfce3f60f4b3d7fa2af80 && \
        $sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/ppc64el/7fa2af80.pub && \
        $sudo apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +5 > cudasign.pub && \
        echo "$NVIDIA_GPGKEY_SUM  cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
        echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/ppc64el /" | $sudo tee /etc/apt/sources.list.d/cuda.list
    fi && \

    print_title "Upgrade OS" | log_lines info && {
        $sudo $apt_get update && \
        $sudo $apt_get install $apt_get_install_options unattended-upgrades && \
        $sudo unattended-upgrades -v
    } && \

    install_cuda_pkgs "online"
}
function install_cuda_offline() {
    print_title "Install offline cuda-repo" | log_lines info && {
        download_and_install $nvidia_repo_baseurl/$cuda_repo_fname
    } && \

    print_title "Upgrade OS" | log_lines info && {
        $sudo $apt_get update && \
        $sudo $apt_get install $apt_get_install_options unattended-upgrades && \
        $sudo unattended-upgrades -v
    } && \

    install_cuda_pkgs "offline"
}
function install_cuda() {
    if [ "$nvidia_repo_src" = "online" ]; then
        install_cuda_online
    elif [ "$nvidia_repo_src" = "offline" ]; then
        install_cuda_offline
    else
        log_error  "Unknown type of cuda repo source, \"$nvidia_repo_src\""
        false
    fi
}
function install_powerai() {
    print_title "Install mldl-repo" | log_lines info && \
    download_and_install $r4_repo_url && \

    print_title "Update OS before installing power-mldl" | log_lines info && \
    $sudo $apt_get update && \

    # remove uncompatible packages
    print_title "Remove legacy openmpi related packages" | log_lines info && \
    {
        # That OpenMPI package conflicts with Ubuntu's non-CUDA-enabled OpenMPI packages.
        # Please uninstall any openmpi or libopenmpi packages before installing IBM Caffe
        # or DDL custom operator for TensorFlow. Purge any configuration files to avoid interference
        local i=0
        while [ $i -lt 2 ];
        do
            local pkgs=`dpkg -l '*openmpi*' | grep "^i.*openmpi" | grep -v ibm | awk '{print $2}' | cut -d: -f1`
            if [ -z "$pkgs" ]; then break; fi
            if [ $i -eq 0 ]; then
                $sudo $apt_get purge -y $pkgs
            else
                log_error "Fail to remove legacy \"openmpi\" related packages before installing powerai's own"
                echo "$lines" | sed -e 's/^/>> /g' | log_lines debug
            fi
            ((i+=1))
        done
        test $i -lt 2
    } && \

    print_title "Install powerai packages" | log_lines info && \
    $sudo $apt_get install $apt_get_install_options power-mldl
}
function install_nvidia_driver() {
    if [ "$nvidia_repo_src" = "offline" ]; then
        print_title "Install offline nvidia-dirver-repo" | log_lines info && {
            download_and_install $nvidia_repo_baseurl/$nvidia_driver_fname
        }
    fi && \
    $sudo $apt_get update && \
    $sudo $apt_get install $apt_get_install_options cuda-drivers
}

if [ `expr match "$1" "^cmd="` -eq 4 ]; then
    cmd=`echo "$1" | cut -d= -f2`
    $cmd $@
    exit $?
fi

install_cuda && \
# NOTE: powerai package requires libcudnn to be installed as deb
# or, we could use the "*_tar" version
install_cudnn6_deb && \
install_powerai && \
if $need_nvidia_driver; then
    install_nvidia_driver
fi
