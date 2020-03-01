#! /usr/bin/env bash


PROG_CLI=${PROG_CLI:-`command -v $0`}
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}


DEFAULT_backup_host=${backup_host:-`hostname -s`}
DEFAULT_backup_dir=${backup_dir:-~/.backup/usb1/pub/backup/docker_containers_at_${DEFAULT_backup_host}}
DEFAULT_volsize=${volsize:-500}
DEFAULT_gpg_passphrase=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}
DEFAULT_include_bind=${include_bind:-false}
DEFAULT_LOG_LEVEL=${LOG_LEVEL:-debug}
DEFAULT_cmd=${cmd:-backup}


source $PROG_DIR/log.sh
source $PROG_DIR/getopt.sh


if [ -z "${container}" ]; then
    log_error "Target \${container} should not be empty. Abort"
    exit 1
fi


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
    #    -e PASSPHRASE=${gpg_passphrase:-shie4Phoh4iMae3eiceegaij7fohtham} \
    #    -v $vol:/volume:ro \
    docker run --rm \
        --hostname ${backup_host} \
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
        echo "# Backup volume \"${vol}\" at container \"${container}\""
        echo "#"
    } | log_lines debug

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
    } | log_lines debug \
    && status_vol \
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
        echo "# Show backup status of volume \"${vol}\" at container \"${container}\""
        echo "#"
    } | log_lines debug

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
        echo "# Verify backup of volume \"${vol}\" at container \"${container}\""
        echo "#"
    } | log_lines debug

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
        echo "# Restore backup of volume \"${vol}\" at container \"${container}\""
        echo "#"
    } | log_lines debug

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
function _vol_op() {
    local cmd=$1

    declare -a vols=()
    # include named volumes
    vols+=(`docker inspect $container | grep -A1 "\"Type\": \"volume\"" | grep "\"Name\":" | cut -d: -f2 | cut -d\" -f2 | sort -u | xargs`)
    # include local bind
    if $incude_bind; then
        vols+=(`docker inspect $container | grep -A1 "\"Type\": \"bind\"" | grep "\"Name\":" | cut -d: -f2 | cut -d\" -f2 | sort -u | xargs`)
    fi
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
}
function backup() { _vol_op ${FUNCNAME[0]} $@; }
function status() { _vol_op ${FUNCNAME[0]} $@; }
function verify() { _vol_op ${FUNCNAME[0]} $@; }
function restore() { _vol_op ${FUNCNAME[0]} $@; }


# issue real cmd
if declare -F $cmd >/dev/null 2>&1; then
    $cmd $@
    exit $?
else
    echo "Unknown cmd \"$cmd\""
    false
fi
