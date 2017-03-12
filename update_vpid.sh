#! /bin/bash

fimg=$1
vid=${vid:-0x0781}
pid=${pid:-0x5571}

USER=${USER:-`whoami`}

if [ "$USER" != "root" ]; then
    sudo=sudo
else
    sudo=""
fi

rc=1
ftmpd=`mktemp -d /tmp/update_vpid.XXXXX`
if $sudo mount -o loop,offset=$((63*512)) $fimg $ftmpd; then
    $sudo sed -i.bak \
        -e 's/vid=0[xX][0-9a-fA-F]\+ /vid='$vid' /g' \
        -e 's/pid=0[xX][0-9a-fA-F]\+ /pid='$pid' /g' \
        $ftmpd/syslinux.cfg && \
    rc=0 && \
    diff -u $ftmpd/syslinux.cfg.bak $ftmpd/syslinux.cfg

    $sudo umount $ftmpd
fi
rmdir $ftmpd 2>/dev/null

exit $rc
