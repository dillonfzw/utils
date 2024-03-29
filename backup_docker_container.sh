#! /usr/bin/env bash


PROG_CLI=${PROG_CLI:-`command -v $0`}
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}


if [ "$DEBUG" == "true" ]; then set -x; fi


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
    echo "    target_folder=foo/bar                  :操作的目标目录，缺省是卷的所有，注意：1)必须是相对路径;2)可以有^@的隐含模式"
    echo "    gpg_passphrase=tho..............u9N    :备份用的秘钥（使用$HOME/.gnupg/的钥匙环）"
    echo "    include_bind=true|*false               :是否操作\"bind\"类型的挂载点"
    echo "    container_name_translate=*true|false   :是否翻译swarm容器名字"
    echo "    container_in_dsk=<container_name>      :备份目录的容器名字，如果被操作容器和备份名字不一样，这里指定"
    echo "    nobackup=.nobackup                     :备份是否忽略存在有指定文件的目录"
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
if echo "${target_folder}" | grep -sq "^@"; then
    target_folder_implicit=true
    target_folder=`echo "${target_folder}" | cut -d\@ -f2`
else
    target_folder_implicit=false
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
    local cmd="docker run --rm \
        --hostname ${backup_host} \
        -e TZ=`date +"%Z%:::z" | tr '+-' '-+'` \
        -v $backup_dir:/.backup \
        -v ~/.gnupg:/home/duplicity/.gnupg \
        -v ~/.cache/duplicity:/home/duplicity/.cache/duplicity \
        -v ~/.ssh:/home/duplicity/.ssh \
        --user root \
        ${_docker_args[@]} \
        wernight/duplicity \
        $@"
    echo "$cmd" | sed -e 's/ \+/ /g' -e 's/ \+-/ \\\\\n  -/g' | sed -e 's/^/>> /g' | log_lines info
    eval $cmd
}
#
# List volume name of a docker container
#
# deps:
# - ${vol}
#
function _ls_vol() {
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
    local _target_folder=${target_folder:+/}${target_folder}
    local args=$@
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Backup(${backup_method}) volume \"${vol}\"'s dir \"${target_folder}\" at container \"${container}\""
        echo "#"
    } | log_lines debug

    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:ro"
    )
    # 对于隐含模式的target_folder备份方式，备份文件写回到顶层目录，而不是以target_folder为子目录
    local _vol=${vol}${_target_folder}
    if ${target_folder_implicit}; then _vol=${vol}; fi

    # nobackup对应的--exclude-if-present需要在任何其他include和exclude参数之前被指定
    # 所以，需要显式的在这里书写
    #--verbosity level, -vlevel
    #   Specify output verbosity level (log level).  Named levels and corresponding values are 0 Error, 2 Warning, 4 Notice (default), 8 Info, 9 Debug (noisiest).
    #   level may also be
    #   a character: e, w, n, i, d
    #   a word: error, warning, notice, info, debug
    _duplicity_docker_run docker_args[@] duplicity \
        $backup_method \
            --verbosity=${LOG_LEVEL:-notice} \
            --allow-source-mismatch \
            --volsize=${volsize} \
            --full-if-older-than=6M \
            ${nobackup:+"--exclude-if-present=${nobackup}"} \
            ${target_folder:+"--include=/volume${_target_folder}"} \
            ${target_folder:+"--exclude=**"} \
            $args \
            /volume \
            file:///.backup/${container_in_dsk}/${_vol} \
    && {
        # log for debug
        echo
        echo "#"
        echo "# content in backup dir for volume \"${vol}\"'s dir \"${target_folder}\" at container \"${container_short}\""
        echo "#"
        ls -lat ${backup_dir}/${container_short}/${vol}${_target_folder} | sed -e 's/^/>> /g'
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
    local _target_folder=${target_folder:+/}${target_folder}
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Show backup status of volume \"${vol}\" at container \"${container_short}\""
        echo "#"
    } | log_lines debug

    # 对于隐含模式的target_folder备份方式，备份文件写回到顶层目录，而不是以target_folder为子目录
    local _vol=${vol}${_target_folder}
    if ${target_folder_implicit}; then _vol=${vol}; fi

    local -a docker_args=(
    )
    _duplicity_docker_run docker_args[@] duplicity \
        collection-status \
            -vnotice \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container_in_dsk}/${_vol} \
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
    local _target_folder=${target_folder:+/}${target_folder}
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# List the files contained in the most current backup of volume \"${vol}\" at container \"${container_short}\""
        echo "#"
    } | log_lines debug

    # 对于隐含模式的target_folder备份方式，备份文件写回到顶层目录，而不是以target_folder为子目录
    local _vol=${vol}${_target_folder}
    if ${target_folder_implicit}; then _vol=${vol}; fi

    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
    )
    _duplicity_docker_run docker_args[@] duplicity \
        list-current-files \
            --allow-source-mismatch \
            $args \
            file:///.backup/${container_in_dsk}/${_vol} \
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
    local _target_folder=${target_folder:+/}${target_folder}
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Verify backup of volume \"${vol}\" at container \"${container_short}\""
        echo "#"
    } | log_lines debug

    # 对于隐含模式的target_folder备份方式，备份文件写回到顶层目录，而不是以target_folder为子目录
    local _vol=${vol}${_target_folder}
    if ${target_folder_implicit}; then _vol=${vol}; fi

    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:ro"
    )
    # 注意：我们采用--file-to-restore的方法，因为：
    # 1) 有可能需要从一个大的备份集里面恢复验证部分内容
    #
    # 这个方法的可能的问题如下：
    # 1) ${vol}${_target_folder}下面按理只应该有目标目录的备份，不会有别的
    # 2) --file-to-restore需要目标目录先建好，动作只回复内容，可能丢失一些目录的设定。
    _duplicity_docker_run docker_args[@] duplicity \
        verify \
            -vnotice \
            --allow-source-mismatch \
            ${target_folder:+"--file-to-restore=${target_folder}"} \
            $args \
            file:///.backup/${container_in_dsk}/${_vol} \
            /volume${_target_folder} \
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
    local _target_folder=${target_folder:+/}${target_folder}
    [ -d "$backup_dir" ] || mkdir -p $backup_dir
    {
        echo
        echo "#"
        echo "# Restore backup of volume \"${vol}\" at container \"${container_short}\""
        echo "#"
    } | log_lines debug

    # 对于隐含模式的target_folder备份方式，备份文件写回到顶层目录，而不是以target_folder为子目录
    local _vol=${vol}${_target_folder}
    if ${target_folder_implicit}; then _vol=${vol}; fi

    local -a docker_args=(
        "-e PASSPHRASE=${gpg_passphrase:-ieniechei7Aihic4oojourie3vaev9ei}"
        "-v $vol:/volume:rw"
    )
    # 注意：我们采用--file-to-restore的方法，因为：
    # 1) 有可能需要从一个大的备份集里面恢复部分内容
    #
    # 这个方法的可能的问题如下：
    # 1) ${vol}${_target_folder}下面按理只应该有目标目录的备份，不会有别的
    # 2) --file-to-restore需要目标目录先建好，动作只回复内容，可能丢失一些目录的设定。
    _duplicity_docker_run docker_args[@] duplicity \
        restore \
            -vnotice \
            --allow-source-mismatch \
            ${target_folder:+"--file-to-restore=${target_folder}"} \
            $args \
            file:///.backup/${container_in_dsk}/${_vol} \
            /volume${_target_folder} \
    && true
}
function _split_vol() {
    local vol_dir=${backup_dir}${container_in_dsk}/${vol}
    local signatures=(`find ${vol_dir}/ \
        -maxdepth 1 \
        \( -type f -o -type l \) \
        -name "duplicity-*-signatures.*.sigtar.gpg" | \
        sed -e 's/^.*-signatures\.\(.*\)\.sigtar.gpg$/\1/g' | \
        sort -u | xargs`)
    local signature
    local FILE
    local fname
    local err_cnt=0
    for signature in ${signatures[@]}
    do true \
     && if [ -f ${vol_dir}/duplicity-full-signatures.${signature}.sigtar.gpg ]; then
            vol_sig_dir=${vol_dir}/full-${signature}
        else
            vol_sig_dir=${vol_dir}/incr-${signature}
        fi \
     && if [ ! -d ${vol_sig_dir} ]; then true \
         && mkdir -p ${vol_sig_dir}.tmp \
         && local exp_cnt=0 \
         && local rel_cnt=0 \
         && for FILE in ${vol_dir}/duplicity-*.${signature}.{sigtar,vol*.difftar,manifest}.gpg
            do true \
             && fname=`basename $FILE` \
             && ((exp_cnt+=1)) \
             && if [ -f "${vol_sig_dir}.tmp/${fname}" ]; then ((rel_cnt+=1)); continue; fi \
             && if [ -L "${FILE}" ]; then continue; fi \
             && true "hard link" \
             && if ! ln $FILE ${vol_sig_dir}.tmp/${fname}; then ((err_cnt+=1)); break; fi \
             && ((rel_cnt+=1)) \
             && true; \
            done \
         && if [ ${err_cnt} -gt 0 ]; then break; fi \
         && if [ $exp_cnt -eq ${rel_cnt} -a $exp_cnt -gt 0 ]; then true \
             && mv ${vol_sig_dir}.tmp ${vol_sig_dir} \
             && true; \
            else true \
             && log_error "Fail to split ${vol}/${signature} with exp(${exp_cnt}) .vs. rel(${rel_cnt})" \
             && ((err_cnt+=1)) \
             && rm -rf ${vol_sig_dir}.tmp \
             && break; \
            fi \
         && for FILE in ${vol_sig_dir}/*.gpg; \
            do true \
             && fname=`basename $FILE` \
             && true rm -f ${vol_dir}/$fname \
             && if [ ! -d ${vol_dir}/.bak ]; then mkdir -p ${vol_dir}/.bak; fi \
             && mv ${vol_dir}/$fname ${vol_dir}/.bak/$fname \
             && ln -s `basename ${vol_sig_dir}`/$fname ${vol_dir}/$fname \
             && true; \
            done \
         && true; \
       fi \
     && {
            printf "%3d %3d %s\n" \
                `ls -1 ${vol_sig_dir}/*.gpg | wc -l` \
                `ls -1 ${vol_sig_dir}/*.vol*.difftar.gpg | wc -l` \
                ${vol}/`basename ${vol_sig_dir}`;
        } | sed -e 's/^/>> /g' | log_lines info \
     && true; \
    done && \
    test ${err_cnt} -eq 0
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

    # 如果显式的exclude_vols集合，和过滤完的vols取补
    declare -a _exclude_vols=(`echo "${exclude_vols}" | tr ',' ' '`)
    declare -p _exclude_vols | sed -e 's/^/>> [__exc_vols]: /g' | log_lines debug
    declare -a vols=`set_difference vols[@] _exclude_vols[@]`
    declare -p vols | sed -e 's/^/>> [final_vols]: /g' | log_lines debug

    local fail_cnt=0
    for vol in ${vols[@]}
    do
        if eval ${cmd}_vol${args:+ ${args}}; then
            true
        else
            ((fail_cnt+=1))
            break
        fi
    done
    test ${fail_cnt} -eq 0
}
function _ls() { _vol_op ${FUNCNAME[0]} $@; }
function full() { _vol_op ${FUNCNAME[0]} $@; }
function incr() { _vol_op ${FUNCNAME[0]} $@; }
function collection-status() { _vol_op ${FUNCNAME[0]} $@; }
function verify() { _vol_op ${FUNCNAME[0]} $@; }
function restore() { _vol_op ${FUNCNAME[0]} $@; }
function list-current-files() { _vol_op ${FUNCNAME[0]} $@; }
function _split() { _vol_op ${FUNCNAME[0]} $@; }

# alias cmds
function backup() { _vol_op incr $@; }
function status() { _vol_op collection-status $@; }
function ls-tree() { _vol_op list-current-files $@; }


# issue real cmd
if [ "$cmd" == "ls" -o "$cmd" == "split" ]; then cmd="_${cmd}"; fi && \
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
    container_in_dsk=${container_in_dsk:-${container_short}} && \
    $cmd $@ && \
    true
else
    echo "Unknown cmd \"$cmd\""
    false
fi
