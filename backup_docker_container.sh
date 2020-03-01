#! /usr/bin/env bash

container=$1; shift
[ -n "${container}" ] || exit 1

cmd=$1; shift; args=$@
[ -n "$cmd" ] || cmd="backup"

backup_host=${backup_host:-`hostname -s`}
backup_dir=${backup_dir:-~fuzhiwen/.backup/usb1/pub/backup/docker_containers_at_${backup_host}}
volsize=${volsize:-500}
gpg_passphrase=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}

#
# Run cmd in a duplicity docker container
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container}
# - ${vol}
# - $(docker_args}
#
function _duplicity_docker_run() {
    # docker的参数，用一种隐晦的方式传送进来
    local -a _docker_args=()
    if echo "${1}" | grep -sq "\[@\]$"; then
        _docker_args+=("${!1}")
        shift
    fi
    docker run --rm \
        --hostname ${backup_host} \
        -e PASSPHRASE=${gpg_passphrase:-shie4Phoh4iMae3eiceegaij7fohtham} \
        -v $vol:/volume:ro \
        -v $backup_dir:/.backup \
        -v ~/.gnupg:/home/duplicity/.gnupg \
        -v ~/.cache/duplicity:/home/duplicity/.cache/duplicity \
        -v ~/.ssh:/home/duplicity/.ssh \
        --user root \
        ${_docker_args[@]} \
        wernight/duplicity \
        $@
}
#
# Backup a docker container
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container}
# - ${vol}
# - ${volsize}
#
function backup_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
    echo
    echo "#"
    echo "# Backup volume \"${vol}\" at container \"${container}\"" 1>&2
    echo "#"
    } 1>&2

    #
    # method 1
    #
    #docker run -it --rm -v $vol:/volume -v $backup_dir:/.backup busybox sh -c "tar -C /volume -zcf - . | split -b 500m - /.backup/${container}_${vol}.tar.gz.split."
    #ls -lat $backup_dir/${container}_${vol}.tar.gz.split.*

    #
    # method 2
    #
    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:ro"
    )
    _duplicity_docker_run docker_args[@] duplicity \
        incremental \
            -vnotice \
            --allow-source-mismatch \
            --volsize=${volsize} \
            --full-if-older-than=6M \
            $args \
            /volume \
            file:///.backup/${container}/${vol} \
    && {
        # log for debug
        echo
        echo "#"
        echo "# content in backup dir for volume \"${vol}\" at container \"${container}\""
        echo "#"
        ls -lat ${backup_dir}/${container}/${vol}/ | sed -e 's/^/>> /g'
    } 1>&2 \
    && true
}
#
# Show status of a docker container's backup
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container}
# - ${vol}
#
function status_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
    echo
    echo "#"
    echo "# Show backup status of volume \"${vol}\" at container \"${container}\"" 1>&2
    echo "#"
    } 1>&2

    #
    # method 2
    #
    local -a docker_args=(
    )
    _duplicity_docker_run docker_args[@] duplicity \
        collection-status \
            -vnotice \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container}/${vol} \
    && true
}
#
# Verify a docker container's backup
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container}
# - ${vol}
#
function verify_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
    echo
    echo "#"
    echo "# Verify backup of volume \"${vol}\" at container \"${container}\"" 1>&2
    echo "#"
    } 1>&2

    #
    # method 2
    #
    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:ro"
    )
    _duplicity_docker_run docker_args[@] duplicity \
        verify \
            -vnotice \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container}/${vol} \
            /volume \
    && true
}
#
# Restore a docker container from backup
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container}
# - ${vol}
#
function restore_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
    echo
    echo "#"
    echo "# Restore backup of volume \"${vol}\" at container \"${container}\"" 1>&2
    echo "#"
    } 1>&2

    #
    # method 2
    #
    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:ro"
    )
    _duplicity_docker_run docker_args[@] duplicity \
        restore \
            -vnotice \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container}/${vol} \
            /volume \
    && true
}


vols=(`docker inspect $container | grep -A1 "\"Type\": \"volume\"" | grep "\"Name\":" | cut -d: -f2 | cut -d\" -f2 | xargs`)
((fail_cnt=0))
for vol in ${vols[@]}
do
    if eval "${cmd}_vol $args"; then
        true
    else
        ((fail_cnt+=1))
        break
    fi
done
test ${fail_cnt} -eq 0
