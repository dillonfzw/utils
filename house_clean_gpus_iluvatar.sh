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
declare -a _flags=()
if true; then true \
 && declare _idx _name \
 && for _idx in `seq 1 ${#@}`; do for _name in silent reset reload; do true \
     && if [ "x${1}" == "x--${_name}" ]; then _flags+=("--${_name}"); shift; fi \
     && if [ "x${1}" == "x--no${_name}" ]; then _flags+=("--no${_name}"); shift; fi \
     && true; \
    done; done \
 && true; \
fi
if [ "${USER:-`whoami`}" == "root" ]; then _sudo=""; else _sudo=/usr/bin/sudo; fi

if true && [ -x ${PROG_DIR}/reset_gpu.sh ]; then true \
 && ${_sudo} ${_sudo:+-n} \
    env cmd=${cmd:-house_clean_gpu} \
        DEFAULT_kernel_module_dir=${DEFAULT_kernel_module_dir} \
        kernel_module_dir=${kernel_module_dir} \
    ${PROG_DIR}/reset_gpu.sh ${_flags[@]} iluvatar ${COREX_SH:-${PROG_DIR}/corex.sh} $@ \
 && true; \
else true \
 && true "Mask the eval's autostart cmd" \
 && declare cmd=true \
 && true "cat reset_gpu.sh | gzip -c | base64 -w80" \
 && eval "$({ cat - <<EOF
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
T2ufQUL1f2Xtf4+3mNC5MAAA
EOF
} | base64 -d | gzip -dc)" \
 && true set -x \
 && house_clean_gpu ${_flags[@]} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
