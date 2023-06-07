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
H4sIAAAAAAAAA81YW2/bNhR+Tn7FqWbEdhvFcbYOqA0Fbbe2C5b2YWvRhyS1ZYmWiciSSkq51NV++w5J
UaZkKYnbYpgfEok61+9ceMh5FnkpjSPgi/h6EiTZhIbZlZu6rNeHFdAbvqTQWQ1HTyybWrl4zOErBIwk
YL98Jn5gfYLHHWsM+e5cSwtIKoUl1OcVibuAv5RlBM53YW+vRYFtf84Iu7W9eJlkKbHdJOEOysIP85gt
3dTx+BWaca7EuTSEJ0f4zmOWgp3h043LAl7oEOrG+FyzLwmEcbNbaWSTbWHsuSHIz86UeIsYrM5zS6gh
aAmBLh/sD2AQdKfamTmcgf0FyVaSK7fgYgzpgkTASJqxCA7HMKcFdcLBjkFY4YBm2NoH7UJwjw/BhhMp
A5tDdx+60D2PzqNuxbFP572zQ/vZxXl/YJ8P0UdtT6OvwUOd1b4G3+JsmVDkJr0zqSqBa0xF6DyfNiK0
kRhlaOr0a3IzBmvvvi0pigiVpPcC4kUPwiKaJB4VxM405Pioa3hIfib4fO2BHU7rLLI4FZOqU/u0rH0K
JZY1dukCelCqzNVbKS1v98plZOKGofCMT+IopBF5gHe2C0Iud3rTJlimfTMUndVPkvjs+QU2GvIZjgQ/
WigXD4tF/T7Edx0uZS8JOQGfeCHaCnaiNGMEXVw3AimJTdcuqfJrIprZQ0LGaUgQerREPY1sqcNED6zf
ydzNwlRKp1EANEoJu0J2yuEp1rMXRz63KoJTdjvRZCjdfB3ZTw8Oqwres1tDOMpc0ghbcoNMTxpbPI3s
Tk/lMsfvxMEc//VwUNWWP34qGtFMJE8/rzmfeZ7TGGhVqD0dU9wPZAiEcVOOkRtCp9crrHgy7PenEl4/
LhEWv9K9NyQFbCck8rH1YXREi1K+FWSGYql32tqJ5Nalcq2i4oXnZcssdFMi0ggbPnaJeC6ViVRoUaa8
LEDUTUXmbKfX2qTE977q7V3V17ubTba/aaJAIYk5p7OQSMMYEfb6Eg2Y3cKC8jRmVFgnFd+FkGHz2mR8
RJ9lC+hrDxr75vYulFWtdlA7IJgDZUmLhRTKvKxWM0rZESJUusny0ksqec8+Xoxk+stQgei7iI4YV2xs
UzlWPZam/8iC470jzYn2PIKyavO6usLqldwS/yh2xf1E/kEA9jNO2H7A4izZ95a+CeO45Jc/1ZKTJRpl
eyLtq0PUeHdnJ6/u6QPpzvGxmFlKi41EKBXILiadmTHiXo412vgjYSPeNVRLI812Fjh/n7x5/+qvtzWC
QqCOFmmKlmb/8+T0dGzY938B26TeQP0EUe9KI4O8KxrpViFYQYdnvigo8U9ojVCrTEq7EFoptq9fC0m5
lsBDglt2rfnqj1rrOsBYBJvFYa4UtXFyd20INsL5PAvD22qFlEm1o7bLmv+qX0e69QsfUVReGxWyKIxd
X7biy6V/9yFjDiFfxn45vPDPYL8Gi6ZskhDCJkuynPjsympI4qq7H6RSuRfWeOGSsIiEgGqykBwcHFhw
dLw3NMQ0xxHpExbPcJRgmzIroWyCqRw3iiITSETukjjWjKIEekWYtQYBddFoHq8nt+OBT64GEUZIGqtr
bS1FU1rGZNOCJoZJ8+Vb4Giy3Y/hfQhWpN0DWcP4+eCM+m/hfvT9gJ/+eLi3wbrViXrKP9iRH15/31F8
DZmEA9SWuSSbtDmYYx8Vra+yrAZ0PSu3tMDiq+76NRHrQbudtcEheT8UujydFK4JtjAOHnT4DJ2pvyQ8
EHtwEX/j9BiFetEiNzTtiEOBe30J3VXC0GroDHMxA8prHnvYdK6OwrtP1XcoV5dHeGRAIeK40I7AIsZp
YeKFxI0Ebk3+qmmau8sE5+iMuwEZYQBef3j327sXb1/Jw2Wp+p959mVBr0k0mNFo4MWM3BzwBRzt/2LV
EkOdA/V0Wvpu3YjJwwLHwUfbVmSWOTFJPuUJX9B5Oq7vFyL86W1CVLZp0/IKwpFAeGjg2yxq5nqXeIqa
YDHNUbEj7/HulhNnzBNtpMaat1mrrifxiCFvsMwv+vLSKW8xOyvtW262oE6BSmFCR9Nv3uzh2DYj84ti
VKv2YwVpU6NS5lSO+k714F8zTDfaChFoB9cD8pamo7i66fe05+L+ot0pRrg6+TrlU4szRbQUmboVWL+M
7OFhK7HR/WorI/vooJ2vcnyrUVD/xliU1wViybguMKzLp+YoXLs0WEejU0Ig0dcVZxijYC4G3XUA1iLk
iQcN0Scew4ayQtrYje3wo0tT2EAr5+BGvriVUWFLi61f6sNzeFVdSpfiPkcN6KaecgepSa+R1U8Qenb/
5uxlPG3J3tKW8kRQz+P7arO6MTu1fbqlOqtU3+db6G9TmUZ/a9h8ndZdeZv+18C/0U/kcNXQDZV9Dde2
TtNVbptVqwZiPdMaFzHv4hSQSmxbXOgERXkgc7flClbu4f8COQRfNuYaAAA=
EOF
} | base64 -d | gzip -dc)" \
 && true set -x \
 && house_clean_gpu ${_flag} iluvatar ${COREX_SH:-/dev/null} $@ \
 && true; \
fi
