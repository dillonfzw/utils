#! /bin/bash



USER=${USER:-`id -u -n`}
if [ "${USER}" != "root" ]; then _sudo=/usr/bin/sudo; else _sudo=""; fi
kernel_module_dir=${kernel_module_dir:-${DEFAULT_kernel_module_dir}}


function reset_gpu_iluvatar() { ${_sudo} ${_sudo:+"-n"} bash -c "source ${backend_profile:-/dev/null}; ixsmi -r ${1:+-i} ${1};"; }
function show_gpu_iluvatar() { ixsmi ${1:+"-i"} ${1} | grep -B99999 "^ *$"; }

function reset_gpu_nvidia() { ${_sudo} ${_sudo:+"-n"} bash -c "source ${backend_profile:-/dev/null}; nvidia-smi -r ${1:+-i} ${1};"; }
function show_gpu_nvidia() { nvidia-smi ${1:+"-i"} ${1} | grep -B99999 "^ *$"; }

function reset_gpu_service() {
    true \
 && local gpu_type=${1:-iluvatar} \
 && if [ -n "${1}" ]; then shift; fi \
 && local backend_profile=${1} \
 && if [ -n "${1}" ]; then source ${backend_profile}; fi \
 && local reset_gpu=reset_gpu_${gpu_type} \
 && local show_gpu=show_gpu_${gpu_type} \
 && while true; \
    do true \
     && if ! ${show_gpu}; then echo "[E]: Fail to list valid GPUs, Abort!" >&2; break; fi \
     && printf "Please input target gpu index: " \
     && local GPU_ID \
     && read GPU_ID \
     && if [ "x${GPU_ID}" == "xbye" ]; then break; fi \
     && if [ "x${GPU_ID}" == "x-1" ]; then unset GPU_ID; fi \
     && ${show_gpu} ${GPU_ID} \
     && printf "Confirm your selected gpu, \"YES\" or \"NO\": " \
     && local YESNO \
     && read YESNO \
     && if [ "x${YESNO}" = "xYES" ]; then true \
         && if echo ${reset_gpu} ${GPU_ID}; then true \
             && echo "[I]: reset ${gpu_type} gpu ${GPU_ID:-all} successfully!" \
             && true; \
            else true \
             && echo "[W]: reset ${gpu_type} gpu ${GPU_ID:-all} failed!" \
             && true; \
            fi \
         && dmesg -H | tail -n10 | sed -e 's/^/[kernel] >> /g' \
         && printf "Press any key to continue." \
         && read _ \
         && clear \
         && true; \
        fi \
     && true; \
    done \
 && true; \
}
function reset_gpu_all() { echo -e "-1\nYES\n\nbye" | reset_gpu_service $@; }

function get_gpu_pids_iluvatar() {
    true \
 && ixsmi ${1:+"-i"} ${1} --query-compute-apps=pid --format=csv | \
    tail -n+2 | sort -u | xargs \
 && true; \
}
function get_pgids_by_pids() {
    true \
 && local _pids=`echo "$@" | sed -e 's/,/ /g'` \
 && if [ -z "${_pids}" ]; then return 0; fi \
 && ps -o pgid= ${_pids} | sort -u | xargs \
 && true; \
}
function get_pids_by_pgids() {
    true \
 && local _pgids=`echo "$@" | tr -s ', ' '\n\n' | sed -e 's/^\([0-9]\)/-\1/g' | xargs` \
 && if [ -z "${_pgids}" ]; then return 0; fi \
 && ps -o pid= ${_pgids} | sort -u | xargs \
 && true; \
}
function get_gpu_pids_ext_iluvatar() {
    true \
 && local _pids=`get_gpu_pids_iluvatar $@` \
 && local _pgids=`get_pgids_by_pids ${_pids}` \
 && local _pids=`get_pids_by_pgids ${_pgids}` \
 && if [ -z "${_pids}" ]; then return 0; fi \
 && echo "${_pids}" \
 && true; \
}
function get_gpu_cnt_iluvatar() {
    true \
 && local _n_pci_cnt=`lspci -n | grep 1e3e | wc -l` \
 && local _n_ixsmi_cnt=`ixsmi -L | grep -i iluvatar | wc -l` \
 && echo ${_n_pci_cnt} ${_n_ixsmi_cnt} \
 && true; \
}
function are_all_gpus_online_iluvatar() {
    true \
 && local -a _cnts=(`get_gpu_cnt_iluvatar`) \
 && if [ ${#_cnts[@]} -eq 2 -a ${_cnts[0]} -eq ${_cnts[1]} ]; then true; else declare -p _cnts; false; fi \
 && true;
}
function get_defunct_apps() {
    true \
 && ps -e -o pid,ppid,stat,cmd | awk '$3 ~ /[DZ]/ { print $0;}' \
 && true; \
}
function kill_gpu_apps_iluvatar() {
    true set -x \
 && local _silent=${_silent:-false} \
 && true "Default killing interval is 5 seconds" \
 && local try_interval=${try_interval:-5.0} \
 && true "Try killing in 5 minutes" \
 && local try_cnt=${try_cnt:-$(echo "scale=0; 60/${try_interval}*5" | bc -l)} \
 && local _succ=true \
 && local -a _pgids=() \
 && local -a _gpu_proc_patterns=(
        "ixsmi"
        "ix-device-plugin"
        ${gpu_proc_patters}
    ) \
 && for _cnt in `seq 1 $((try_cnt+1))`
    do true \
     && true "Get extended gpu pids" \
     && local -a _pids=(`get_gpu_pids_ext_iluvatar ${1}`) \
     && true "Accumulate the pgds of gpu apps" \
     && local -a _pgids=($(echo ${_pgids[@]} $(get_pgids_by_pids ${_pids[@]}) | tr ' ' '\n' | sort -u | xargs)) \
     && true "Get possible gpu related pids by historical pgids" \
     && local _name \
     && local -a _pids=($(echo ${_pids[@]} $(for _name in ${_gpu_proc_patterns[@]}; do pgrep -f ${_name}; done) $(get_pids_by_pgids ${_pgids[@]}) | tr ' ' '\n' | sort -u | xargs)) \
     && if [ ${#_pids} -ge 1 -a ${_cnt} -gt ${try_cnt} ]; then true \
         && _succ=false \
         && echo "[W]: kill apps on gpu ${1:-all} failed!" >&2 \
         && if ! ${_silent}; then true \
             && { ps -H -o pid,ppid,pgid,user,group,cmd ${_pids[@]}; \
                  ixsmi pmon -c 1 ${1:+"-i"} ${1};
             } | sed -e 's/^/[W]: >> /g' >&2 \
             && true; \
            fi \
         && break; \
        elif [ ${#_pids} -ge 1 ]; then true \
         && local _sig=SIGTERM \
         && if [ ${_cnt} -ge ${try_cnt} ]; then _sig=SIGKILL; fi \
         && if ! ${_silent}; then true \
             && { ps -H -o pid,ppid,pgid,user,group,cmd ${_pids[@]}; \
                  echo "------------------------------------------------------------"; \
                  ixsmi pmon -c 1 ${1:+"-i"} ${1}; \
                } | sed -e 's/^/[I]: '${_sig}'ing >> /g' >&2 \
             && true; \
            fi \
         && { ${_sudo} ${_sudo:+"-n"} kill -${_sig} ${_pids[@]} || true; } \
         && sleep ${try_interval} \
         && true; \
        else true \
         && _succ=true \
         && echo "[I]: kill apps on gpu ${1:-all} successfully!" >&2 \
         && break; \
        fi \
     && true; \
    done \
 && ${_succ}; \
}
function get_drv_kmd() {
    true set -x \
 && local _drv_dir=${_drv_dir:-${kernel_module_dir}} \
 && local _drv_name=${1:-iluvatar} \
 && local _drv_file="" \
 && if [ -z "${_drv_dir}" -o ! -d "${_drv_dir}" ]; then true \
     && _drv_file=`modinfo ${_drv_name} | grep "^filename:" | awk '{print $2}'` \
     && true; \
    else true \
     && _drv_file=`find ${_drv_dir}/ ${_drv_dir}/*/ -maxdepth 1 -name "${_drv_name}*" 2>/dev/null | head -n1` \
     && true; \
    fi \
 && if [ -z "${_drv_file}" -o ! -f "${_drv_file}" ]; then echo "[W]: ${_drv_name} does not exists in \"${_drv_dir}\"!" >&2; return 1; fi \
 && echo ${_drv_file} \
 && true; \
}
function _xx_drv_kmd() {
    true set -x \
 && local _op=${1} && shift \
 && if [ "x${1}" == "x--dry-run" ]; then _dry_run_prefix="echo"; shift; fi \
 && if [ "x${1}" == "x--" ]; then shift; fi \
 && local _drv_name=${1:-iluvatar} && shift \
 && local _drv_file="" \
 && if echo "${_drv_name}" | grep -sq "\.ko$"; then true \
     && _drv_file=${_drv_name} \
     && _drv_name=`basename ${_drv_name} .ko` \
     && true; \
    fi \
 && if [ "x${_op}" == "xload" ]; then true \
     && local _op1="modprobe" \
     && local _op2="insmod" \
     && true; \
    elif [ "x${_op}" == "xunload" ]; then true \
     && local _op1="modprobe -r" \
     && local _op2="rmmod" \
     && true; \
    else echo "[E]: Unknown operation \"${_op}\", Abort!" >&2; false; fi \
 && if [ -z "${_drv_file}" ] && modinfo ${_drv_name} >/dev/null 2>&1; then true \
     && true "驱动是在系统注册的，直接按名字操作" \
     && eval ${_dry_run_prefix} ${_sudo} ${_sudo:+"-n"} ${_op1} ${_drv_name} \
     && true; \
    elif [ "x${_op}" == "xload" ]; then true \
     && true "按文件载入驱动模块" \
     && local _drv_dir=${_drv_dir:-${kernel_module_dir:-/lib/modules/`uname -r`/}} \
     && local _drv_file=${_drv_file:-`get_drv_kmd ${_drv_name}`} \
     && if [ -n "${_drv_file}" -a -f "${_drv_file}" ]; then true \
         && eval ${_dry_run_prefix} ${_sudo} ${_sudo:+"-n"} ${_op2} ${_drv_file} \
         && true; \
        fi \
     && true; \
    elif [ "x${_op}" == "xunload" ]; then true \
     && true "按名字卸载驱动模块就可以了，因为已经载入内核了" \
     && eval ${_dry_run_prefix} ${_sudo} ${_sudo:+"-n"} ${_op2} ${_drv_name} \
     && true; \
    fi \
 && true; \
}
function load_drv_kmd() { _xx_drv_kmd load $@; }
function unload_drv_kmd() { _xx_drv_kmd unload $@; }
declare -F unload_gpu_kmd_iluvatar >/dev/null 2>&1 || \
function unload_gpu_kmd_iluvatar() {
    true \
 && if lsmod | grep -sq -F "itr_peer_mem_drv"; then true \
     && echo "[I]: Unloading kernel module itr_peer_mem_drv ..." 2>&1 \
     && { unload_drv_kmd itr_peer_mem_drv || true; } \
     && true; \
    fi \
 && local _kmd_name="" \
 && if lsmod | grep -sq -F iluvatar; then true \
     && _kmd_name="iluvatar" \
     && true; \
    elif lsmod | grep -sq -F bi_driver ; then true \
     && _kmd_name="bi_driver" \
     && true; \
    fi \
 && if [ -n "${_kmd_name}" ]; then true \
     && echo "[I]: Unloading kernel module ${_kmd_name} ..." 2>&1 \
     && unload_drv_kmd ${_kmd_name} \
     && true; \
    fi \
 && true; \
}
declare -F load_gpu_kmd_iluvatar >/dev/null 2>&1 || \
function load_gpu_kmd_iluvatar() {
    true set -x \
 && local _drv_name \
 && local _succ_cnt=0 \
 && for _drv_name in iluvatar bi_driver itr_peer_mem_drv; do true \
     && if [ "${_drv_name}" == "itr_peer_mem_drv" -a ${_succ_cnt} -ne 1 ]; then break; fi \
     && if [ "${_drv_name}" == "bi_driver" -a ${_succ_cnt} -eq 1 ]; then continue; fi \
     && local _drv_file=`get_drv_kmd ${_drv_name}` \
     && if [ -z "${_drv_file}" -o ! -f "${_drv_file}" ]; then continue; fi \
     && echo "[I]: Loading kernel module ${_drv_name} from ${_drv_file} ..." 2>&1 \
     && if load_drv_kmd ${_drv_file}; then ((_succ_cnt+=1)); true; fi \
     && true; \
    done \
 && test ${_succ_cnt} -ge 1 \
 && true; \
}
declare -F reload_gpu_kmd_iluvatar >/dev/null 2>&1 || \
function reload_gpu_kmd_iluvatar() {
    true \
 && if [ -f /opt/init_kmd.sh ]; then ${_sudo} ${_sudo:+-n} bash -l -c "/opt/init_kmd.sh"; return $?; fi \
 && local _sleep_interval=${1:-${_sleep_interval:-5.0}} \
 && unload_gpu_kmd_iluvatar \
 && sleep ${_sleep_interval} \
 && load_gpu_kmd_iluvatar \
 && true; \
}
function show_last_reload_kmd_log_iluvatar() {
    true \
 && local _nl=`dmesg -H | grep iluvatar | nl | grep "exit$" | awk '{print $1}' | tail -n -1` \
 && if [ -z "${_nl}" ]; then return 0; fi \
 && dmesg -H | grep iluvatar | tail -n +$((_nl+1)) \
 && true; \
}
function house_clean_gpu() {
    true set -x \
 && true "sample usage: ${FUNCNAME[0]} {--silent|--reset|--reload|--kill} iluvatar ~fuzhiwen/bin/corex.sh 2,4" \
 && local _idx _name \
 && local _silent=false \
 && local _reset=false \
 && local _reload=false \
 && local _kill=false \
 && for _idx in `seq 1 ${#@}`; do for _name in silent reset reload kill; do true \
     && if [ "x${1}" == "x--${_name}" ]; then eval _${_name}=true; shift; fi \
     && if [ "x${1}" == "x--no${_name}" ]; then eval _${_name}=false; shift; fi \
     && true; \
    done; done \
 && true "\"reload\" takes priority..." \
 && if ${_reload}; then _reset=false; _kill=true; fi \
 && if ${_reset}; then _reload=false; _kill=true; fi \
 && true "default to use \"kill\"..." \
 && if [ "x${_reset}${_reload}" == "xfalsefalse" ]; then _kill=true; fi \
 && local gpu_type=${1:-iluvatar} \
 && if [ -n "${1}" ]; then shift; fi \
 && local backend_profile=${1} \
 && if [ -n "${1}" ]; then source ${backend_profile}; shift; fi \
 && local _gpu_ids="$@" \
 && local show_gpu=show_gpu_${gpu_type} \
 && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[bef] >> /g'; fi \
 && if ${_kill}; then true \
     && local kill_gpu_apps=kill_gpu_apps_${gpu_type} \
     && $kill_gpu_apps "$@" \
     && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[kil] >> /g'; fi \
     && true; \
    fi \
 && if ${_reset}; then true \
     && local reset_gpu=reset_gpu_${gpu_type} \
     && local _reset_cnt=${_reset_cnt:-10} \
     && local _reset_interval=${_reset_interval:-2.0} \
     && local _reset_succ=false \
     && local _idx \
     && for _idx in `seq 1 ${_reset_cnt}`; \
        do true \
         && if $reset_gpu "$@"; then _reset_succ=true; break; fi \
         && if [ ${_idx} -ge ${_reset_cnt} ]; then break; fi \
         && echo "[I]: Wait ${_reset_interval}s and try resetting ${_idx} of ${_reset_cnt} times" >&2 \
         && sleep ${_reset_interval} \
         && true; \
        done \
     && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[rst] >> /g'; fi \
     && ${_reset_succ}; \
    fi \
 && if ${_reload}; then true \
     && local reload_gpu_kmd=reload_gpu_kmd_${gpu_type} \
     && $reload_gpu_kmd \
     && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[rld] >> /g'; fi \
     && true; \
    fi \
 && local show_last_reload_kmd_log=show_last_reload_kmd_log_${gpu_type} \
 && if ! $_silent; then $show_last_reload_kmd_log | sed -e 's/^/[kernel] >> /g'; fi \
 && local are_all_gpus_online=are_all_gpus_online_${gpu_type} \
 && if ! ${are_all_gpus_online}; then echo "[W]: Not all gpus are online." >&2; false; fi \
 && true; \
}


if [ "x${cmd}" == "x" -a "x${1}" != "x" -a "x`type -t ${1}`" == "xfunction" ]; then cmd=${1}; shift; fi
if [ "x${1}" == "--" ]; then shift; fi
${cmd:-reset_gpu_service} $@
