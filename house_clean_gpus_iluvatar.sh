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
2v8BCS9N5WUtAAA=
EOF
} | base64 -d | gzip -dc)" \
 && true set -x \
 && house_clean_gpu ${_flag} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
