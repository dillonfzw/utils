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
ARCH=${ARCH:-`uname -m`}

DEFAULT_workspace=$HOME/workspace
DEFAULT_ovpn_server_dir=/etc/openvpn/server

source getopt.sh

function initialize_ovpn_server() {
    local tmpd=`mktemp -d /tmp/XXXXXXXX`

    # install openvpn
    local ovpn_server_dir=$ovpn_server_dir && \

    rsync -av /usr/share/easy-rsa $tmpd/ && \
    rsync -av /usr/share/doc/easy-rsa-*/ $tmpd/easy-rsa/ && \

    # https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04
    # https://www.jianshu.com/p/cd2496dbf5bd
    if cd $tmpd/easy-rsa/3.0/; then
        ./easyrsa init-pki && \
        ./easyrsa build-ca nopass && \
        ./easyrsa gen-req server nopass && \
        ./easyrsa sign-req server server && \
        ./easyrsa gen-req client nopass && \
        ./easyrsa sign-req client client && \
        ./easyrsa gen-dh && \
        openvpn --genkey --secret pki/ta.key && \

        cd - >/dev/null 
    else
        false
    fi && \

    # config ovpn
    $sudo rsync -av $tmpd/ $ovpn_server_dir/ && \
    $sudo ln -s easy-rsa/3.0/pki $ovpn_server_dir/pki && \
    $sudo cp -a /usr/share/doc/openvpn-*/sample/sample-config-files/{server,client}.conf \
                $ovpn_server_dir/ && \
    $sudo sed -i -e 's/^ca /#ca /g' \
              -e 's/^cert /#cert /g' \
              -e 's/^key /#key /g' \
              -e 's/^dh /#dh /g' \
              -e 's/^tls-auth /#tls-auth /g' $ovpn_server_dir/server.conf && \
    echo "
<ca>
$(<$tmpd/easy-rsa/3.0/pki/ca.crt)
</ca>
<cert>
$(<$tmpd/easy-rsa/3.0/pki/issued/server.crt)
</cert>
<key>
$(<$tmpd/easy-rsa/3.0/pki/private/server.key)
</key>
<dh>
$(<$tmpd/easy-rsa/3.0/pki/dh.pem)
</dh>
<tls-auth>
$(<$tmpd/easy-rsa/3.0/pki/ta.key)
</tls-auth>
key-direction 0
cd /etc/openvpn/server
" | $sudo tee -a $ovpn_server_dir/server.conf && \

    # start service
    do_and_verify \
       "$sudo test -L /etc/openvpn/server.conf"  \
       "$sudo ln -s $ovpn_server_dir/server.conf /etc/openvpn" \
       "true" && \
    $sudo systemctl enable openvpn@server.service && \
    if do_and_verify \
        "eval $sudo systemctl status openvpn@server.service | grep -sq 'Active: active'" \
        "$sudo systemctl start openvpn@server.service" \
        "sleep 10"; then
        $sudo systemctl status openvpn@server.service | log_lines debug
    else
        log_error "Fail to start openvpn@server.service" | log_lines error
        false
    fi

    rc=$?
    rm -rf $tmpd
    (exit $rc)
}
function install_pam_google_authenticator() {
    # install libpam-google-authenticator
    if cd $workspace; then
        if [ ! -d google-authenticator-libpam ]; then
            git clone https://github.com/google/google-authenticator-libpam.git
        fi && \
        if cd google-authenticator-libpam; then
            pkgs=${pkgs}${pkgs:+ }" \
                rpm:autoconf \
                rpm:automake \
                rpm:libtool \
                rpm:rpm-build \
            " && \
            if do_and_verify "pkg_verify $pkgs" "pkg_install $pkgs" "true"; then
                pkg_list_installed $pkgs
            else
                log_error "Fail to install pkgs \"`filter_pkgs $pkgs | xargs`\""
                false
            fi && \

            ./bootstrap.sh && \
            ./configure && \
            make dist && \
            if [ ! -d $HOME/rpmbuild/SOURCES ]; then mkdir -p $HOME/rpmbuild/SOURCES; fi && \
            cp google-authenticator-*.tar.gz $HOME/rpmbuild/SOURCES/ && \
            rpmbuild -bb ./contrib/rpm.spec && \
            pkg_install_rpm $HOME/rpmbuild/RPMS/$ARCH/google-authenticator-*.rpm && \
            cd - >/dev/null
        fi
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

    pkgs=${pkgs}${pkgs:+ }" \
        rpm:google-authenticator \
    " && \
    if do_and_verify "pkg_verify $pkgs" "install_pam_google_authenticator" "true"; then
        pkg_list_installed $pkgs
    else
        log_error "Fail to install google-authenticator"
        false
    fi && \

    setup_route
}

if [ -n "$cmd" ]; then
    $cmd "$@"
    exit $?
else
    usage
fi
