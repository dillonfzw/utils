#! /usr/bin/env bash


export PATH=/usr/sbin:/usr/bin:/usr/local/bin:$PATH


MONITOR_HOST=${MONITOR_HOST:-10.209.0.7}
GW_IPADDR=${GW_IPADDR:-`ip route get ${MONITOR_HOST} | grep -w src | head -n1 | sed -e 's/^.*src *//g' | awk '{print $1}'`}
HOSTNAME_s=${HOSTNAME_s:-`hostname -s`}


dig @${MONITOR_HOST} +timeout=1 +retry=0 +noall `echo "${HOSTNAME_s}.${GW_IPADDR}" | tr '.' '-'`.fake.com >/dev/null 2>&1 || true
