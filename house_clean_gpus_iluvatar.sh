#! /usr/bin/env bash


PROG_CLI=${PROG_CLI:-$0}
if echo "$PROG_CLI" | grep -sq "^\/"; then
    PROG_CLI=`command -v $PROG_CLI`
fi
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}
if [ "${PROG_DIR}" == "${PROG_NAME}" ]; then
    PROG_DIR=.
fi


# sample usage:
# $ ./house_clean_gpus_iluvatar.sh
# [aft] >> +-------------------------------+----------------------+----------------------+
# [aft] >> | 4    Iluvatar BI-V100         | 00000000:1E:00.0     | 1500MHz   1200MHz    |
# [aft] >> | 0%   32C   P0    55W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [aft] >> +-------------------------------+----------------------+----------------------+
# [aft] >> | 5    Iluvatar BI-V100         | 00000000:21:00.0     | 25MHz     33MHz      |
# [aft] >> | 0%   0C    P0    65535W / 250 | 513MiB / 32768MiB    | 100%      Default    |
# [aft] >> +-------------------------------+----------------------+----------------------+
# [aft] >> | 6    Iluvatar BI-V100         | 00000000:25:00.0     | 1500MHz   1200MHz    |
# [aft] >> | 0%   31C   P0    57W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [aft] >> +-------------------------------+----------------------+----------------------+
# [aft] >> | 7    Iluvatar BI-V100         | 00000000:2D:00.0     | 1500MHz   1200MHz    |
# [aft] >> | 0%   29C   P0    55W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [aft] >> +-------------------------------+----------------------+----------------------+
# [aft] >>
# GPU 00000000:14:00.0  was successfully reset.
# GPU 00000000:15:00.0  was successfully reset.
# GPU 00000000:18:00.0  was successfully reset.
# GPU 00000000:1D:00.0  was successfully reset.
# GPU 00000000:1E:00.0  was successfully reset.
# GPU 00000000:21:00.0  was successfully reset.
# GPU 00000000:25:00.0  was successfully reset.
# GPU 00000000:2D:00.0  was successfully reset.
# All done.
# [fin] >> Timestamp    Sun May 14 08:04:27 2023
# [fin] >> +-----------------------------------------------------------------------------+
# [fin] >> |  IX-ML: 3.0.1       Driver Version: 3.0.1       CUDA Version: 10.2          |
# [fin] >> |-------------------------------+----------------------+----------------------|
# [fin] >> | GPU  Name                     | Bus-Id               | Clock-SM  Clock-Mem  |
# [fin] >> | Fan  Temp  Perf  Pwr:Usage/Cap|      Memory-Usage    | GPU-Util  Compute M. |
# [fin] >> |===============================+======================+======================|
# [fin] >> | 0    Iluvatar BI-V100         | 00000000:14:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   31C   P0    54W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >> | 1    Iluvatar BI-V100         | 00000000:15:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   31C   P0    56W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >> | 2    Iluvatar BI-V100         | 00000000:18:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   30C   P0    54W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >> | 3    Iluvatar BI-V100         | 00000000:1D:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   31C   P0    56W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >> | 4    Iluvatar BI-V100         | 00000000:1E:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   32C   P0    55W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >> | 5    Iluvatar BI-V100         | 00000000:25:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   31C   P0    57W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >> | 6    Iluvatar BI-V100         | 00000000:2D:00.0     | 1500MHz   1200MHz    |
# [fin] >> | 0%   30C   P0    55W / 250W   | 513MiB / 32768MiB    | 0%        Default    |
# [fin] >> +-------------------------------+----------------------+----------------------+
# [fin] >>

COREX_SH=`command -v corex.sh 2>/dev/null`
if [ "x${1}" == "x--silent" ]; then _flag="--silent"; shift; fi

if [ -x ${PROG_DIR}/reset_gpu.sh ]; then true \
 && sudo -n env cmd=${cmd:-house_clean_gpu} ${PROG_DIR}/reset_gpu.sh ${_flag} iluvatar ${COREX_SH:-${PROG_DIR}/corex.sh} $@ \
 && true; \
else true \
 && declare USER=${USER:-`id -u -n`} \
 && if [ "${USER}" != "root" ]; then sudo=sudo; else sudo=""; fi \
 && eval "$({ cat - <<EOF
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
oRMU5aHM3Y4rWLmH/wuBWEeDmBoAAA==
EOF
} | base64 -d | gzip -dc)" \
 && set -x \
 && house_clean_gpu ${_flag} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
