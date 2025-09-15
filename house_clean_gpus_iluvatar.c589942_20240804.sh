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
# $ ./house_clean_gpus_iluvatar.sh reset
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

COREX_SH=${COREX_SH:-`command -v corex.sh 2>/dev/null`}
declare -a _flags=()
if true; then true \
 && declare _idx _name \
 && for _idx in `seq 1 ${#@}`; do for _name in silent kill reset reload; do true \
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
aTMAAA==
EOF
} | base64 -d | gzip -dc)" \
 && true set -x \
 && house_clean_gpu ${_flags[@]} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
