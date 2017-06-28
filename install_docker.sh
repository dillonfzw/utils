#! /bin/bash

PROGCLI=$0
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=1.0.1


# constant variables
USER=${USER:-`whoami`}
ARCH=`uname -m`

eval "OS_ID=`grep "^ID=" /etc/os-release | cut -d= -f2-`"
eval "OS_VER=`grep "^VERSION_ID=" /etc/os-release | cut -d= -f2-`"
PKGNAME=docker-engine
typeset -A docker_repo_urls
docker_repo_urls["ubuntu-16.04-ppc64le"]="deb http://ftp.unicamp.br/pub/ppc64el/ubuntu/16_04/docker-1.12.6-ppc64el/ xenial main"
docker_repo_urls["ubuntu-14.04-ppc64le"]="deb http://ftp.unicamp.br/pub/ppc64el/ubuntu/14_04/docker-ppc64el/ trusty main"
TOKEN="${OS_ID}-${OS_VER}-${ARCH}"
docker_repo_url=${docker_repo_urls[$TOKEN]}


sudo_const="sudo -n"
if [ "$USER" != "root" ]; then
    sudo="$sudo_const"
fi


# default values of input parameters


# import common libraries
source $PROGDIR/log.sh
source $PROGDIR/getopt.sh


# logic to valid input parameter
if [ "$cwsrole" = "cn" -a -z "$cwsmn" ]; then
    log_error "You must specify a valid CwS MN, \"cwsmn\", in order to install and setup a CwS CN" >&2
    exit 1
fi

setup_repo="setup_repo_${OS_ID}"
install_pkg="install_pkg_${OS_ID}"

function setup_repo_ubuntu() {
    local i=0
    while [ $i -lt 2 ];
    do
        lines="`apt-cache pkgnames ${PKGNAME} 2>/dev/null`"
        if echo "$lines" | grep -sq -x "${PKGNAME}"; then
            if [ $i -eq 0 ]; then
                log_info "\"${PKGNAME}\" was already in the apt cache."
                echo "$lines" | sed -e 's/^/>> /g' | log_lines debug
            fi
            break

        elif [ $i -eq 0 ]; then
            log_info "Configure repo for package \"${PKGNAME}\"..."
            echo "$docker_repo_url" | $sudo tee /etc/apt/sources.list.d/docker.list && \
            $sudo apt-get update

        elif [ $i -eq  1 ]; then
            log_error "Fail to setup repo for package \"${PKGNAME}\""
        fi
        ((i+=1))
    done
    test $i -lt 2
}
function install_pkg_ubuntu() {
    local i=0
    while [ $i -lt 2 ];
    do
        lines=`dpkg -l "${PKGNAME}" 2>&1`
        if echo "$lines" | grep -sq "^ii \+${PKGNAME} "; then
            if [ $i -eq 0 ]; then
                log_info "\"${PKGNAME}\" was already installed."
                echo "$lines" | sed -e 's/^/>> /g' | log_lines debug
            fi
            break

        elif [ $i -eq 0 ]; then
            log_info "Install package \"${PKGNAME}\"..."
            $sudo apt-get install -y ${PKGNAME}

        elif [ $i -eq 1 ]; then
            log_error "Fail to install package \"${PKGNAME}\""
        fi
        ((i+=1))
    done
    test $i -lt 2
}

$setup_repo && \
$install_pkg
