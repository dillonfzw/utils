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


reset_gpu_service $@
