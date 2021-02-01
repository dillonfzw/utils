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
DEFAULT_cmd=${cmd:-ls}
DEFAULT_container_name_translate=${container_name_translate:=true}


function usage() {
    echo "Usage: ${PROG_NAME} [options]"
    echo "Options:"
    echo "   *container=<container_name>             :被操作的目标容器"
    echo "   *cmd={backup|status|verify|restore:*ls} :操作指令"
    echo "    include_vols=<vol1>,<vol2>             :一定要操作的卷,逗号分割,缺省是所有"
    echo "    exclude_vols=<vol1>,<vol2>             :排除掉不要操作的卷,逗号分割,缺省是没有要排除的卷,注意:排除操作优先!"
    echo "    LOG_LEVEL=*debug|info|warning|error    :日志等级"
    echo "    backup_dir=~/.backup/usb1/backup       :备份的目标本地目录"
    echo "    gpg_passphrase=tho..............u9N    :备份用的对称秘钥"
    echo "    include_bind=true|*false               :是否操作\"bind\"类型的挂载点"
    echo "    container_name_translate=*true|false   :是否翻译swarm容器名字"
    echo "    volsize=*500                           :备份卷的大小"
}
#
# 查询容器的全名，消除swarm等添加后缀的造成的备份恢复错误
#
# deps:
# - ${container}
#
function get_container_long_name() {
    docker ps --format "{{.ID}}\t{{.Names}}" | awk "\$2 ~ /^${container}/{print \$2;}"
}
#
# 获取容器的短名，消除swarm等添加后缀的造成的备份恢复错误
#
# deps:
# - ${container}
#
function get_container_short_name() {
    echo "${container}" | cut -d\. -f1
}


source $PROG_DIR/log.sh
source $PROG_DIR/getopt.sh
source $PROG_DIR/utils.sh


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
        -e TZ=`date +"%Z%:::z" | tr '+-' '-+'` \
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
# List volume name of a docker container
#
# deps:
# - ${vol}
#
function ls_vol() {
    echo "${vol}"
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
    local backup_method=${backup_method:-"incr"}
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Backup(${backup_method}) volume \"${vol}\" at container \"${container}\""
        echo "#"
    } | log_lines debug

    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:ro"
    )
    _duplicity_docker_run docker_args[@] duplicity \
        $backup_method \
            -vnotice \
            --allow-source-mismatch \
            --volsize=${volsize} \
            --full-if-older-than=6M \
            $args \
            /volume \
            file:///.backup/${container_short}/${vol} \
    && {
        # log for debug
        echo
        echo "#"
        echo "# content in backup dir for volume \"${vol}\" at container \"${container_short}\""
        echo "#"
        ls -lat ${backup_dir}/${container_short}/${vol}/ | sed -e 's/^/>> /g'
    } | log_lines debug \
    && status_vol \
    && true
}
function incr_vol() {
    local backup_method="incr"
    backup_vol $@
}
function full_vol() {
    local backup_method="full"
    backup_vol $@
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
function collection-status_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Show backup status of volume \"${vol}\" at container \"${container_short}\""
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
            file:///.backup/${container_short}/${vol} \
    && true
}
function status_vol() {
    collection-status_vol $@
}
#
# Show files of a docker container's backup
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container}
# - ${vol}
#
function list-current-files_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# List the files contained in the most current backup of volume \"${vol}\" at container \"${container_short}\""
        echo "#"
    } | log_lines debug

    local -a docker_args=(
    )
    _duplicity_docker_run docker_args[@] duplicity \
        list-current-files \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container_short}/${vol} \
    && true
}
#
# Verify a docker container's backup
#
# deps:
# - ${backup_host}
# - ${PASSPHRASE} if sym enc
# - ${backup_dir}
# - ${container_short}
# - ${vol}
#
function verify_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Verify backup of volume \"${vol}\" at container \"${container_short}\""
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
            file:///.backup/${container_short}/${vol} \
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
# - ${container_short}
# - ${vol}
#
function restore_vol() {
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Restore backup of volume \"${vol}\" at container \"${container_short}\""
        echo "#"
    } | log_lines debug

    #
    # method 2
    #
    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:rw"
    )
    _duplicity_docker_run docker_args[@] duplicity \
        restore \
            -vnotice \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container_short}/${vol} \
            /volume \
    && true
}
function _vol_op() {
    local cmd=$1; shift
    local args=$@

    local -a vols=()
    function _gen_vol_filter() {
        grep -Ev "^\/sys\/|^\/dev\/|^\/proc\/"
    }
    # include named volumes
    vols+=(`docker inspect ${container_long} | \
            grep -A1 "\"Type\": \"volume\"" | grep "\"Name\":" | \
            cut -d: -f2 | cut -d\" -f2 | sort -u | \
            _gen_vol_filter | \
            xargs`)
    declare -p vols | sed -e 's/^/>> [named_vols]: /g' | log_lines debug
    # include local bind
    if $include_bind; then
        vols+=(`docker inspect ${container_long} | \
                grep -A1 "\"Type\": \"bind\"" | grep "\"Source\":" | \
                cut -d: -f2 | cut -d\" -f2 | sort -u | \
                _gen_vol_filter | \
                xargs`)
    fi
    declare -p vols | sed -e 's/^/>> [__all_vols]: /g' | log_lines debug

    # 如果有显式的include_vols集合，和实际的vols取交
    declare -a _include_vols=(`echo "${include_vols}" | tr ',' ' '`)
    declare -p _include_vols | sed -e 's/^/>> [__inc_vols]: /g' | log_lines debug
    if [ 0 -lt ${#_include_vols} ]; then
        declare -a vols=`set_intersection vols[@] _include_vols[@]`
    fi

    # 如果显式的exclude_vols集合，和过滤玩的vols取补
    declare -a _exclude_vols=(`echo "${exclude_vols}" | tr ',' ' '`)
    declare -p _exclude_vols | sed -e 's/^/>> [__exc_vols]: /g' | log_lines debug
    declare -a vols=`set_difference vols[@] _exclude_vols[@]`
    declare -p vols | sed -e 's/^/>> [final_vols]: /g' | log_lines debug

    local fail_cnt=0
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
function ls() { _vol_op ${FUNCNAME[0]} $@; }
function full() { _vol_op ${FUNCNAME[0]} $@; }
function incr() { _vol_op ${FUNCNAME[0]} $@; }
function collection-status() { _vol_op ${FUNCNAME[0]} $@; }
function verify() { _vol_op ${FUNCNAME[0]} $@; }
function restore() { _vol_op ${FUNCNAME[0]} $@; }
function list-current-files() { _vol_op ${FUNCNAME[0]} $@; }

# alias cmds
function backup() { _vol_op incr $@; }
function status() { _vol_op collection-status $@; }
function ls-tree() { _vol_op list-current-files $@; }


# issue real cmd
if declare -F $cmd >/dev/null 2>&1; then
    if [ "${container_name_translate}" = "true" ]; then
        container_long=`get_container_long_name ${container}` && \
        if [ -z "${container_long}" ]; then
            log_error "Fail to get container ${container}'s long name. Abort!"
        fi && \
        container_short=`get_container_short_name ${container}` && \
        if [ -z "${container_short}" ]; then
            log_error "Fail to get container ${container}'s short name. Abort!"
        fi && \
        true;
    else
        container_long=${container}
        container_short=${container}
    fi && \
    $cmd $@ && \
    true
else
    echo "Unknown cmd \"$cmd\""
    false
fi
