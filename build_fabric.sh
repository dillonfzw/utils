#! /bin/bash

# dlmfabric home
# .../pcc/build_two/bldsrv/cws/dli_mainline/dli_fabric/linux-rh7_ppc64le/dlmfabric
dlmfabric_home=${dlmfabric_home:-`pwd`}

# dlm_home
# .../pcc/build_two/bldsrv/cws/dli_mainline/dli_bld/linux-ppc64le/dlm
# .../pcc/build_two/bldsrv/cws/dli_mainline/dli_bld/linux-x86_64/dlm
# we expect the dlm_home is in following relative directory
dlm_home=${dlm_home:-"$dlmfabric_home/../../../dli_bld/linux-${ARCH}/dlm"}

is_rhel=true
is_ubuntu=false

ARCH=${ARCH:-`uname -m`}
USER=`whoami`
if [ "$USER" = "root" ]; then sudo=""; else sudo=sudo; fi

[ -n "$docker_img" ] || \
if $is_rhel; then
    docker_img=fuzhiwen/dlcn-rhel7-`uname -m`:cuda8.0-cudnn6-devel
else
    docker_img=fuzhiwen/dlcn-ubuntu1604-`uname -m`:r4
fi

# prepare docker env
$sudo systemctl start docker.service
echo "[I]: Pull docker image $docker_img"
docker pull $docker_img

# create dlcn-m2 storage volume
if ! docker ps -a --format="{{.Names}}" | grep -sq -x dlcn-m2; then
    echo "[I]: initialize dlcn-m2"
    docker run --name dlcn-m2 \
        -v /home/dlspark/.m2 \
        -v /home/dlspark/.cache \
        -v /root/.m2 \
        -v /root/.cache \
        `if uname -m | grep -x -sq ppc64le; then echo "ppc64le/"; fi`busybox
fi

# build in container
set -x
docker run -it --rm \
  --volumes-from dlcn-m2 \
  -v $dlm_home:/home/dlspark/workspace/dlm \
  -v $dlmfabric_home:/home/dlspark/workspace/dlmfabric \
  $docker_img \
  env dlmfabric_home=/home/dlspark/workspace/dlmfabric \
      FIX_PERM=true AUTO_BUILD=true \
  /home/dlspark/workspace/dlm/scripts/build_dli_comps.sh cmd=build_dlmfabric

# deliver the package
pkg=`ls -1 build/fabric-*-linux-${ARCH}.tar.gz | sort -V | tail -n1`
if [ -n "$pkg" ]; then
    echo zrelease -mc -d ${FABRIC_PKG_DIR} $pkg
else
    echo "[E]: Fail to pick up package file" >&2
    false
fi
