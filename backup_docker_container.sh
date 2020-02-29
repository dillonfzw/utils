#! /usr/bin/env bash

container=$1
backup_host=vpn1
backup_dir=~fuzhiwen/.backup/usb1/pub/backup/docker_containers_at_`hostname -s`

vols=(`docker inspect $container | grep -A1 "\"Type\": \"volume\"" | grep "\"Name\":" | cut -d: -f2 | cut -d\" -f2 | xargs`)
for vol in ${vols[@]}
do
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    echo "Backup volume \"${vol}\" at container \"${container}\""
    #docker run -it --rm -v $vol:/volume -v $backup_dir:/.backup busybox sh -c "tar -C /volume -zcf - . | split -b 500m - /.backup/${container}_${vol}.tar.gz.split."
    #ls -lat $backup_dir/${container}_${vol}.tar.gz.split.*
    docker run --rm \
        -e PASSPHRASE=${PASSPHRASE:-ieniechei7Aihic4oojourie3vaev9ei} \
        -v $vol:/volume:ro \
        -v $backup_dir:/.backup \
        -v ~/.cache:/home/duplicity/.cache/duplicity \
        -v ~/.gnupg:/home/duplicity/.gnupg \
        -v ~/.ssh:/home/duplicity/.ssh \
        -v ~/.boto:/home/duplicity/.boto:ro \
        --user root \
        wernight/duplicity \
        duplicity \
            --allow-source-mismatch \
            --volsize=500 \
            --full-if-older-than=6M \
            /volume \
            file:///.backup/${container}/${vol}
    ls -lat $backup_dir/${container}/${vol}
done
