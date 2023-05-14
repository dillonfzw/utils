#! /bin/bash


function reset_gpu_iluvatar() { ixsmi -r ${1:+"-i"} ${1}; }
function show_gpu_iluvatar() { ixsmi ${1:+"-i"} ${1} | grep -B99999 "^ *$"; }

function reset_gpu_nvidia() { nvidia-smi -r ${1:+"-i"} ${1}; }
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
function kill_gpu_apps_iluvatar() {
    true \
 && local try_cnt=${try_cnt:-300} \
 && local try_interval=${try_interval:-2.0} \
 && local _succ=true \
 && for _cnt in `seq 1 $((try_cnt+1))`
    do true \
     && local -a _pids=(`get_gpu_pids_iluvatar ${1}` `pidof ixsmi`) \
     && if [ ${#_pids} -ge 1 -a ${_cnt} -gt ${try_cnt} ]; then true \
	 && _succ=false \
	 && echo "[W]: kill apps on gpu ${1:-all} failed!" >&2 \
	 && { ps -o pid,ppid,user,group,cmd ${_pids[@]}; \
	      ixsmi pmon -c 1 ${1:+"-i"} ${1}; \
	    } | sed -e 's/^/[W]: >> /g' >&2 \
	 && break; \
        elif [ ${#_pids} -ge 1 ]; then true \
         && local _sig=SIGKILL \
         && if [ ${_cnt} -le 2 ]; then _sig=SIGTERM; fi \
	 && { ps -o pid,ppid,user,group,cmd ${_pids[@]}; \
	      ixsmi pmon -c 1 ${1:+"-i"} ${1}; \
	    } | sed -e 's/^/[I]: '${_sig}'ing >> /g' >&2 \
	 && { kill -${_sig} ${_pids[@]} || true; } \
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
 && local reset_gpu=reset_gpu_${gpu_type} \
 && local show_gpu=show_gpu_${gpu_type} \
 && local kill_gpu_apps=kill_gpu_apps_${gpu_type} \
 && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[bef] >> /g'; fi \
 && $kill_gpu_apps "$@" \
 && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[aft] >> /g'; fi \
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
 && ${_reset_succ} \
 && if ! $_silent; then $show_gpu "$@" | sed -e 's/^/[fin] >> /g'; fi \
 && if ! $_silent; then dmesg -H | tail -n10 | sed -e 's/^/[kernel] >> /g'; fi \
 && true; \
}


${cmd:-reset_gpu_service} $@
