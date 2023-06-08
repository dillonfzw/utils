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

if false && [ -x ${PROG_DIR}/reset_gpu.sh ]; then true \
 && sudo -n env cmd=${cmd:-house_clean_gpu} ${PROG_DIR}/reset_gpu.sh ${_flag} iluvatar ${COREX_SH:-${PROG_DIR}/corex.sh} $@ \
 && true; \
else true \
 && declare USER=${USER:-`id -u -n`} \
 && if [ "${USER}" != "root" ]; then sudo=sudo; else sudo=""; fi \
 && true "Mask the eval's autostart cmd" \
 && declare cmd=true \
 && true "cat reset_gpu.sh | gzip -c | base64 -w80" \
 && eval "$({ cat - <<EOF
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
Yfvl/l/Rtz/oYSIAAA==
EOF
} | base64 -d | gzip -dc)" \
 && true set -x \
 && house_clean_gpu ${_flag} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
