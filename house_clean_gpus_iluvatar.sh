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
if [ "${USER:-`whoami`}" == "root" ]; then _sudo=""; else _sudo=/usr/bin/sudo; fi

if true && [ -x ${PROG_DIR}/reset_gpu.sh ]; then true \
 && ${_sudo} ${_sudo:+-n} \
    env cmd=${cmd:-house_clean_gpu} \
        DEFAULT_kernel_module_dir=${DEFAULT_kernel_module_dir} \
        kernel_module_dir=${kernel_module_dir} \
    ${PROG_DIR}/reset_gpu.sh ${_flag} iluvatar ${COREX_SH:-${PROG_DIR}/corex.sh} $@ \
 && true; \
else true \
 && true "Mask the eval's autostart cmd" \
 && declare cmd=true \
 && true "cat reset_gpu.sh | gzip -c | base64 -w80" \
 && eval "$({ cat - <<EOF
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
EOF
} | base64 -d | gzip -dc)" \
 && true set -x \
 && house_clean_gpu ${_flag} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
