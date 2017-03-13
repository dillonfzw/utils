#! /bin/bash

fimg=$1

[ -n "$entrypoint" ] || \
entrypoint=${2:-dsm60}

vid=${vid:-0x0781}
pid=${pid:-0x5571}
mac1=${mac1:-00:e0:4c:7a:e3:a7}
mac1=`echo "$mac1" | sed -e 's/://g' | tr 'a-f' 'A-F'`

menuentry=${menuentry:-bare}
menuentry_tool='XPEnology Configuration Tool v2.2'
menuentry_bare='XPEnology DS3615xs 6.0.2-8451.5 Baremetal'
saved_entry=`eval "echo \\\$menuentry_$menuentry"`

USER=${USER:-`whoami`}

if [ "$USER" != "root" ]; then
    sudo=sudo
else
    sudo=""
fi

function dsm52() {
    local rc=1
    local ftmpd=`mktemp -d /tmp/update_vpid.XXXXX`
    if $sudo mount -o loop,offset=$((63*512)) $fimg $ftmpd; then
        $sudo sed -i.bak \
            -e 's/vid=0[xX][0-9a-fA-F]\+ /vid='$vid' /g' \
            -e 's/pid=0[xX][0-9a-fA-F]\+ /pid='$pid' /g' \
            $ftmpd/syslinux.cfg && \
        rc=0 && \
        diff -u $ftmpd/syslinux.cfg.bak $ftmpd/syslinux.cfg

        # output for debug
        grep -nHE " vid=0x| pid=0x" $ftmpd/syslinux.cfg
        $sudo umount $ftmpd
    fi
    rmdir $ftmpd 2>/dev/null

    return $rc
}
function dsm60() {
    local rc=1
    local ftmpd=`mktemp -d /tmp/update_vpid.XXXXX`
    if $sudo mount -o loop,offset=$((2048*512)) $fimg $ftmpd; then
        $sudo sed -i.bak \
            -e 's/^set vid=.*$/set vid='$vid'/g' \
            -e 's/^set pid=.*$/set pid='$pid'/g' \
            -e 's/^set mac1=.*$/set mac1='$mac1'/g' \
            $ftmpd/grub/grub.cfg && \
        $sudo sed -i.bak \
            -e 's/^saved_entry=.*$/saved_entry=='"$saved_entry"'/g' \
            $ftmpd/grub/grubenv && \
        rc=0 && \
        for FILE in $ftmpd/grub/{grub.cfg,grubenv}; do
            diff -u $FILE.bak $FILE; \
        done

        # output for debug
        grep -nHE "^set vid=|^set pid=" $ftmpd/grub/grub.cfg
        grep -nHE "^saved_entry=" $ftmpd/grub/grubenv
        $sudo umount $ftmpd
    fi
    rmdir $ftmpd 2>/dev/null

    return $rc
}

$entrypoint
