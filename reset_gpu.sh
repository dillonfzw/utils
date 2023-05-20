#! /bin/bash



USER=${USER:-`id -u -n`}
if [ "${USER}" != "root" ]; then sudo=sudo; else sudo=""; fi


function reset_gpu_iluvatar() { $sudo ${sudo:+"-n"} ixsmi -r ${1:+"-i"} ${1}; }
function show_gpu_iluvatar() { ixsmi ${1:+"-i"} ${1} | grep -B99999 "^ *$"; }

function reset_gpu_nvidia() { $sudo ${sudo:+"-n"} nvidia-smi -r ${1:+"-i"} ${1}; }
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
     && ${show_gpu} \
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
    tail +2 | sort -u | xargs \
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
 && local _pgids=`echo "$@" | sed -e 's/ \+/,/g'` \
 && if [ -z "${_pgids}" ]; then return 0; fi \
 && ps -o pid= -g ${_pgids} | sort -u | xargs \
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
 && local _n_pci_cnt=`lspci | grep 1e3e | wc -l` \
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
    true \
 && true "Default killing interval is 5 seconds" \
 && local try_interval=${try_interval:-5.0} \
 && true "Try killing in 5 minutes" \
 && local try_cnt=${try_cnt:-$(echo "scale=0; 60/${try_interval}*5" | bc -l)} \
 && local _succ=true \
 && local -a _pgids=() \
 && for _cnt in `seq 1 $((try_cnt+1))`
    do true \
     && true "Get extended gpu pids" \
     && local -a _pids=(`get_gpu_pids_ext_iluvatar ${1}`) \
     && true "Accumulate the pgds of gpu apps" \
     && local -a _pgids=($(echo ${_pgids[@]} $(get_pgids_by_pids ${_pids[@]}) | tr ' ' '\n' | sort -u | xargs)) \
     && true "Get possible gpu related pids by historical pgids" \
     && local -a _pids=($(echo ${_pids[@]} $(pidof ixsmi) $(get_pids_by_pgids ${_pgids[@]}) | tr ' ' '\n' | sort -u | xargs)) \
     && if [ ${#_pids} -ge 1 -a ${_cnt} -gt ${try_cnt} ]; then true \
	 && _succ=false \
	 && echo "[W]: kill apps on gpu ${1:-all} failed!" >&2 \
	 && { ps -H -o pid,ppid,pgid,user,group,cmd ${_pids[@]}; \
	      ixsmi pmon -c 1 ${1:+"-i"} ${1}; \
	    } | sed -e 's/^/[W]: >> /g' >&2 \
	 && break; \
        elif [ ${#_pids} -ge 1 ]; then true \
         && local _sig=SIGTERM \
         && if [ ${_cnt} -ge ${try_cnt} ]; then _sig=SIGKILL; fi \
	 && { ps -H -o pid,ppid,pgid,user,group,cmd ${_pids[@]}; \
	      ixsmi pmon -c 1 ${1:+"-i"} ${1}; \
	    } | sed -e 's/^/[I]: '${_sig}'ing >> /g' >&2 \
	 && { $sudo ${sudo:+"-n"} kill -${_sig} ${_pids[@]} || true; } \
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
function unload_gpu_kmd_iluvatar() {
    true \
 && if lsmod | grep -sq -F "itr_peer_mem_drv"; then true \
     && { $sudo ${sudo:+"-n"} modprobe -r itr_peer_mem_drv || true; } \
     && true; \
    fi \
 && local _kmd_name="bi_driver" \
 && if modinfo iluvatar >/dev/null 2>&1; then _kmd_name="iluvatar"; fi \
 && if lsmod | grep -sq -F ${_kmd_name}; then true \
     && $sudo ${sudo:+"-n"} modprobe -r ${_kmd_name} \
     && true; \
    fi \
 && true; \
}
function load_gpu_kmd_iluvatar() {
    true \
 && local _kmd_name="bi_driver" \
 && if modinfo iluvatar >/dev/null 2>&1; then _kmd_name="iluvatar"; fi \
 && if ! lsmod | grep -sq -F ${_kmd_name}; then true \
     && $sudo ${sudo:+"-n"} modprobe ${_kmd_name} \
     && true; \
    fi \
 && if ! lsmod | grep -sq -F itr_peer_mem_drv; then true \
     && { $sudo ${sudo:+"-n"} modprobe itr_peer_mem_drv || true; } \
     && true; \
    fi \
 && true; \
}
function reload_gpu_kmd_iluvatar() {
    true \
 && unload_gpu_kmd_iluvatar \
 && load_gpu_kmd_iluvatar \
 && true; \
}
function show_last_reload_kmd_log_iluvatar() {
    true \
 && local _nl=`dmesg -H | grep iluvatar | nl | grep "exit$" | awk '{print $1}' | tail -1` \
 && if [ -z "${_nl}" ]; then return 0; fi \
 && dmesg -H | grep iluvatar | tail +$((_nl+1)) \
 && true; \
}
function house_clean_gpu() {
    true \
 && true "sample usage: ${FUNCNAME[0]} iluvatar ~fuzhiwen/bin/corex.sh 2,4" \
 && local _silent=false \
 && if [ "x${1}" == "x--silent" ]; then _silent=true; shift; fi \
 && local gpu_type=${1:-iluvatar} \
 && if [ -n "${1}" ]; then shift; fi \
 && local backend_profile=${1} \
 && if [ -n "${1}" ]; then source ${backend_profile}; shift; fi \
 && local _gpu_ids="$@" \
 && local show_gpu=show_gpu_${gpu_type} \
 && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[bef] >> /g'; fi \
 && if true; then true \
     && local kill_gpu_apps=kill_gpu_apps_${gpu_type} \
     && $kill_gpu_apps "$@" \
     && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[kil] >> /g'; fi \
     && true; \
    fi \
 && if false; then true \
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
 && if true; then true \
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


${cmd:-reset_gpu_service} $@
