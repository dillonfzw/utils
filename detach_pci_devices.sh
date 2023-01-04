#! /usr/bin/env bash


#
# Hook this script to docker.service's startup procedure
#
# $ sudo systemctl edit docker.service
# [Service]
# ExecStartPre=-/usr/local/bin/detach_pci_devices.sh
#
# $ sudo systemctl daemon-reload
# $ sudo systemctl cat docker.service
#


# turn on to trace the program
#exec >>/tmp/log.111 2>&1
#set -x


# on-the-fly "detach_pci_dev" to debug
function _detach_pci_dev() { echo "detech_pci_dev $@"; }
function detach_pci_devices_4_ubuntu1804_10_209_16_17() {
    true \
 && true "------------------------ Iluvatar devices ----------------------------" \
 && true 'fuzhiwen@ubuntu1804:~/bin$ ixsmi | grep "Iluvatar"' \
 && true '| 0    Iluvatar MR50            | 00000000:17:00.0     | 500MHz    1600MHz    |' \
 && true '| 1    Iluvatar MR100           | 00000000:35:00.0     | 1000MHz   1600MHz    |' \
 && true '| 2    Iluvatar MR100           | 00000000:36:00.0     | 1000MHz   1600MHz    |' \
 && true '| 3    Iluvatar MR100           | 00000000:9C:00.0     | 1000MHz   1600MHz    |' \
 && true '| 4    Iluvatar MR50            | 00000000:9D:00.0     | 500MHz    1600MHz    |' \
 && true '| 5    Iluvatar MR50            | 00000000:A0:00.0     | 500MHz    1600MHz    |' \
 && true '| 6    Iluvatar MR50            | 00000000:A4:00.0     | 500MHz    1600MHz    |' \
 && true 'fuzhiwen@ubuntu1804:~/bin$ ixsmi -L' \
 && true 'GPU 0: Iluvatar MR50 (UUID: GPU-9724efd1-11af-4c7f-b6d0-5abc10fabfea)' \
 && true 'GPU 1: Iluvatar MR100 (UUID: GPU-ab801ea4-cda7-4b3b-b6c3-4331bf72abfc)' \
 && true 'GPU 2: Iluvatar MR100 (UUID: GPU-b994251c-bf2b-4254-b1b8-9e3c4576bd52)' \
 && true 'GPU 3: Iluvatar MR100 (UUID: GPU-60ff0b9a-ce83-45d6-80c9-8b02bf71ee47)' \
 && true 'GPU 4: Iluvatar MR50 (UUID: GPU-d2e5e91d-83da-42f4-b668-fa0f89f24296)' \
 && true 'GPU 5: Iluvatar MR50 (UUID: GPU-?????)' \
 && true 'GPU 6: Iluvatar MR50 (UUID: GPU-47432c7f-2aeb-4d26-8f1a-74d013ef4dc2)' \
 && true "------------------------ Nvidia devices ----------------------------" \
 && true 'fuzhiwen@ubuntu1804:~/bin$ nvidia-smi  | grep 00000' \
 && true '|   0  Tesla T4            On   | 00000000:39:00.0 Off |                    0 |' \
 && true '|   1  Tesla T4            On   | 00000000:3C:00.0 Off |                    0 |' \
 && true '|   2  NVIDIA GeForce ...  On   | 00000000:3D:00.0 Off |                  N/A |' \
 && true 'fuzhiwen@ubuntu1804:~/bin$ nvidia-smi -L' \
 && true 'GPU 0: Tesla T4 (UUID: GPU-de28d35c-5c4e-f26c-0811-3b6cbcd923f9)' \
 && true 'GPU 1: Tesla T4 (UUID: GPU-5664e386-1859-588e-9cf5-ed4f6afba1d4)' \
 && true 'GPU 2: NVIDIA GeForce RTX 2060 (UUID: GPU-aacedcb9-999f-f3c1-1f55-49f0c996d27a)' \
 && local -a _devs=(
        #
        # Iluvatar devices
        #
        #"0000:17:00.0"
        #"0000:35:00.0"
        #"0000:36:00.0"
        "0000:9C:00.0"
        #"0000:9D:00.0"
        "0000:A0:00.0"
        #"0000:A4:00.0"
        #
        # Nvidia devices
        #
        #"0000:39:00.0"
        #"0000:3C:00.0"
        #"0000:3D:00.0"
    ) \
 && for_each_op --silent detach_pci_dev ${_devs[@]} \
 && true;
}


HOSTNAME_s=`hostname -s`
MAJOR_IP_ADDR=`ip route get 8.8.8.8 | grep via | head -n1 | sed -e 's/.*src \(.*\) uid.*$/\1/g' | tr '.' '_'`
HOST_PREFIX=${HOSTNAME_s}_${MAJOR_IP_ADDR}

LOG_LEVEL=${LOG_LEVEL:-debug}
as_root=${as_root:-true}
sudo=${sudo:-/usr/bin/sudo}

declare _SCRIPT_HOME=~fuzhiwen/bin
export PATH=$_SCRIPT_HOME:$PATH
source log.sh
source utils.sh


detach_pci_devices_4_${HOST_PREFIX} $@
