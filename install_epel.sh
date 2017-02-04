#! /bin/bash

USER=${USER:-`whoami`}
epel_url=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# install epel yum repo
function install_epel() {
    local sudo=""

    # add prefix "sudo" if NOT root
    [ "$USER" != "root" ] && sudo=sudo
    
    # install epel repo
    # but disable it by default
    if ! yum list installed epel-release | grep -sq epel-release; then
        $sudo yum install -y $epel_url && \
        $sudo sed -i -e 's/enabled=1/enabled=0/g' /etc/yum.repos.d/epel.repo
    fi
}

install_epel
