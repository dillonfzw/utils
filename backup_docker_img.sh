#! /usr/bin/env bash

img=$1
backup_host=vpn1
backup_dir=~fuzhiwen/.backup/usb1/pub/backup/docker_images_at_`hostname -s`/

set -x
docker save $img | ssh $backup_host 7za a -bt -si -v500m -t7z $backup_dir/`echo ${img} | tr ':' '_'`.img.7z
