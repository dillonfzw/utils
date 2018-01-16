#! /usr/bin/env bash

#               ------------------------------------------
#               THIS SCRIPT PROVIDED AS IS WITHOUT SUPPORT
#               ------------------------------------------

PROGCLI=`command -v $0`
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=1.0.1

function listFunctions() {
    grep "^function " $PROGCLI | sed -e 's/^.*function *\(.*\)(.*$/\1/g'
}
function usage() {
    echo "Usage $PROGNAME"
    listFunctions | sed -e 's/^/[cmd] >> /g' | log_lines info
    exit 0
}

source log.sh
source getopt.sh
source utils.sh

[ "$DEBUG" = "true" ] && set -x

[ `whoami` = 'root' ] || sudo=sudo
workspace=$HOME/workspace

function initialize_ovpn_server() {
    # install openvpn
    ovpn_server_dir=/etc/openvpn/server && \

    mkdir -p $ovpn_server_dir && \
    rsync -av /usr/share/easy-rsa $ovpn_server_dir/ && \

    # https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04
    # https://www.jianshu.com/p/cd2496dbf5bd
    if cd $ovpn_server_dir/easy-rsa/2.0; then
        source vars && \
        ./build-ca && \
        ./build-key-server server && \
        ./build-dh && \
        openvpn --genkey --secret keys/ta.key && \
        ./build-key-pass client && \
        cd - >/dev/null 
    fi && \

    # config ovpn
    if cd $ovpn_server_dir; then
        ln -s easy-rsa/2.0/keys ./keys && \
        cp -a /usr/share/doc/openvpn-*/sample/sample-config-files/{server,client}.conf ./ && \

        cd - >/dev/null
    fi && \


    $sudo ln -s $ovpn_server_dir/server.conf /etc/openvpn && \
    $sudo systemctl enable openvpn@server.service && \
    $sudo systemctl start openvpn@server.service && \
    $sudo systemctl status openvpn@server.service
}

function main() {
    # openvpn and easy-rsa are for openvpn service
    # pamtester are testing openvpn pam config
    # quagga are for dynamic route support
    # pam-devel is required when building libpam-google-authenticator
    pkgs=${pkgs}${pkgs:+ }" \
        rpm:openvpn \
        rpm:easy-rsa \
        rpm:pamtester \
        rpm:quagga \
        rpm:pam-devel \
        rpm:git \
        rpm:rsync \
    " && \
    if do_and_verify "pkg_verify $pkgs" "pkg_install $pkgs" "true"; then
        pkg_list_installed $pkgs
    else
        log_error "Fail to install pkgs \"`filter_pkgs $pkgs | xargs`\""
        false
    fi && \

    if [ ! -d $workspace ]; then
        mkdir -p $workspace
    fi && \

    # install libpam-google-authenticator
    if cd $workspace; then
        git clone https://github.com/google/google-authenticator-libpam.git && \
        cd google-authenticator-libpam && \
        ./bootstrap.sh && \
        ./configure && \
        make dist && \
        if [ -d $HOME/rpmbuild/SOURCES ]; then mkdir -p $HOME/rpmbuild/SOURCES; fi && \
        cp google-authenticator-*.tar.gz $HOME/rpmbuild/SOURCES/ && \
        rpmbuild -bb ./contrib/rpm.spec && \
        $sudo yum install ~/rpmbuild/RPMS/$ARCH/google-authenticator-*.rpm && \
        cd - >/dev/null
    fi && \



    # enable ip forwarding
    cmds="enable
    configure terminal
    ip forwarding
    exit
    show running
    write"
    IFS_OLD="$IFS"
    IFS=$'\n'
    for cmd in $cmds
    do
        IFS="$IFS_OLD"
        [ -n "$cmd" ] || continue
        $sudo vtysh -d zebra -c $cmd
    done
}

if [ `expr match "$1" "^cmd="` -eq 4 ]; then
    cmd=`echo "$1" | cut -d= -f2`
    shift
    $cmd "$@"
    exit $?
else
    usage
fi
