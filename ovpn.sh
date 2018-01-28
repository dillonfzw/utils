#! /usr/bin/env bash

#               ------------------------------------------
#               THIS SCRIPT PROVIDED AS IS WITHOUT SUPPORT
#               ------------------------------------------

PROGCLI=`command -v $0`
PROGNAME=${0##*/}
PROGDIR=${0%/*}
PROGVERSION=1.0.0

source log.sh
source utils.sh

[ "$DEBUG" = "true" ] && set -x

[ `whoami` = 'root' ] || sudo=sudo

DEFAULT_workspace=$HOME/workspace
DEFAULT_ovpn_server_dir=/etc/openvpn/server

source getopt.sh

function initialize_ovpn_server() {
    # install openvpn
    local ovpn_server_dir=$ovpn_server_dir && \

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

    # start service
    do_and_verify \
       "test -L /etc/openvpn/server.conf"  \
       "$sudo ln -s $ovpn_server_dir/server.conf /etc/openvpn" \
       "true" && \
    $sudo systemctl enable openvpn@server.service && \
    if do_and_verify \
        "$sudo systemctl status openvpn@server.service | grep -sq 'Active: active'" \
        "$sudo systemctl start openvpn@server.service" \
        "sleep 10"; then
        $sudo systemctl status openvpn@server.service | log_lines debug
    else
        log_error "Fail to start openvpn@server.service" | log_lines error
        false
    fi
}
function install_pam_google_authenticator() {
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
    fi
}
function setup_route() {
    # activate zebra
    if do_and_verify \
        'eval $sudo systemctl status zebra | grep -sq "Active: active .running."' \
        'eval $sudo systemctl enable zebra && $sudo systemctl start zebra' \
        "true"; then
        $sudo systemctl status zebra | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to start up zebra service"
        $sudo systemctl status zebra | sed -e 's/^/>> /g' | log_lines error
        false
    fi && \

    # enable ip forwarding
    $sudo vtysh \
        -c "configure terminal" \
        -c "ip forwarding" \
        -c "exit" \
        -c "show running" \
        -c "write"
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

    echo install_pam_google_authenticator && \

    setup_route
}

if [ -n "$cmd" ]; then
    $cmd "$@"
    exit $?
else
    usage
fi
