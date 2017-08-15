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
install_nvidia_driver=${install_nvidia_driver:-false}

#############################
# app related variables
#
# refer to official web link:
# https://ibm.biz/powerai
# https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/README.html
r4_repo_url=${r4_repo_url:-"https://public.dhe.ibm.com/software/server/POWER/Linux/mldl/ubuntu/mldl-repo-network_4.0.0_ppc64el.deb"}

DEFAULT_cuda_repo_src=online
cuda_repo_src=${cuda_repo_src:-$DEFAULT_cuda_repo_src}

nvidia_repo_baseurl=${nvidia_repo_baseurl:-"ftp://bejgsa.ibm.com/gsa/home/f/u/fuzhiwen/Public/nvidia"}
nvidia_driver_fname=${nvidia_driver_fname:-"nvidia-driver-local-repo-ubuntu1604-384.59_1.0-1_ppc64el.deb"}

CUDA_VERSION=${CUDA_VERSION:-8.0}
CUDA_PKG_VERSION=`echo $CUDA_VERSION | tr '.' '-'`

cuda_repo_fname=${cuda_repo_fname:-"cuda-repo-ubuntu1604-8-0-local-ga2v2_8.0.61-1_ppc64el.deb"}

DEFAULT_cudnn_fnames=${DEFAULT_cudnn_fnames}${DEFAULT_cudnn_fnames:+ }"libcudnn6_6.0.20-1+cuda8.0_ppc64el.deb"
DEFAULT_cudnn_fnames=${DEFAULT_cudnn_fnames}${DEFAULT_cudnn_fnames:+ }"libcudnn6-dev_6.0.20-1+cuda8.0_ppc64el.deb"
DEFAULT_cudnn_fnames=${DEFAULT_cudnn_fnames}${DEFAULT_cudnn_fnames:+ }"libcudnn6-doc_6.0.20-1+cuda8.0_ppc64el.deb"
cudnn_fnames=${cudnn_fnames:-$DEFAULT_cudnn_fnames}

cache_home=${cache_home:-$HOME/.cache}
cache_powerai_download=${cache_powerai_download:-$cache_home/powerai/download}


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
    fi
    if [ -f $cache_powerai_download/$f ]; then
        $sudo dpkg -i $cache_powerai_download/$f
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
function install_cuda_pkgs() {
    print_title "Install $1 cuda runtime pkgs" | log_lines info && {
        $sudo apt-get install -y --allow-unauthenticated --no-install-recommends \
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
            ln -s cuda-$CUDA_VERSION /usr/local/cuda
        fi && \
        f=/etc/ld.so.conf.d/cuda.conf && if [ ! -f $f ]; then
            echo "/usr/local/cuda/lib" >> $f
            echo "/usr/local/cuda/lib64" >> $f
        fi && \
        f=/etc/ld.so.conf.d/nvidia.conf && if [ ! -f $f ]; then
            echo "/usr/local/nvidia/lib" >> $f
            echo "/usr/local/nvidia/lib64" >> $f
        fi
    } && \

    print_title "Install $1 cuda development pkgs" | log_lines info && {
        $sudo apt-get install -y --allow-unauthenticated --no-install-recommends \
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
function install_nvidia_online() {
    print_title "Install online cuda repo" | log_lines info && \
    if [ ! -f /etc/apt/sources.list.d/cuda.list ]; then
        # https://github.com/dillonfzw/nvidia-docker/blob/ppc64le/ubuntu-16.04/cuda/8.0/runtime/Dockerfile.ppc64le
        NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
        NVIDIA_GPGKEY_FPR=ae09fe4bbd223a84b2ccfce3f60f4b3d7fa2af80 && \
        $sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/ppc64el/7fa2af80.pub && \
        $sudo apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +5 > cudasign.pub && \
        echo "$NVIDIA_GPGKEY_SUM  cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
        echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/ppc64el /" | $sudo tee /etc/apt/sources.list.d/cuda.list
    fi && \

    print_title "Upgrade OS" | log_lines info && {
        $sudo apt-get update && \
        $sudo apt-get install -y unattended-upgrades && \
        $sudo unattended-upgrades -v
    } && \

    install_cuda_pkgs "online" && \

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
function install_nvidia_offline() {
    if [ "$install_nvidia_driver" = "true" ]; then
        print_title "Install offline nvidia-dirver" | log_lines info && \
        download_and_install $nvidia_repo_baseurl/$nvidia_driver_fname
    fi && \

    print_title "Install offline cuda-repo" | log_lines info && {
        download_and_install $nvidia_repo_baseurl/$cuda_repo_fname
    } && \

    print_title "Upgrade OS" | log_lines info && {
        $sudo apt-get update && \
        $sudo apt-get install -y unattended-upgrades && \
        $sudo unattended-upgrades -v
    } && \

    install_cuda_pkgs "offline" && \

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
function install_nvidia() {
    if [ "$cuda_repo_src" = "online" ]; then
        install_nvidia_online
    elif [ "$cuda_repo_src" = "offline" ]; then
        install_nvidia_offline
    else
        false
    fi
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
