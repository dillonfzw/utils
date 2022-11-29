#! /bin/bash


function reset_gpu_iluvatar() { ixsmi -r -i ${1}; }
function show_gpu_iluvatar() { ixsmi ${1:+"-i"} ${1} | grep -B99999 "^ *$"; }

function reset_gpu_nvidia() { nvidia-smi -r -i ${1}; }
function show_gpu_nvidia() { nvidia-smi ${1:+"-i"} ${1} | grep -B99999 "^ *$"; }

function reset_gpu_service() {
    local gpu_type=${1:-iluvatar} \
 && if [ -n "${1}" ]; then shift; fi \
 && local backend_profile=${1} \
 && if [ -n "${1}" ]; then source ${backend_profile}; fi \
 && local reset_gpu=reset_gpu_${gpu_type} \
 && local show_gpu=show_gpu_${gpu_type} \
 && while true; \
    do true \
     && ${show_gpu} \
     && printf "Please input target gpu index: " \
     && read GPU_ID \
     && ${show_gpu} ${GPU_ID} \
     && printf "Confirm your selected gpu, \"YES\" or \"NO\": " \
     && read YESNO \
     && if [ "x${YESNO}" = "xYES" ]; then true \
         && if ${reset_gpu} ${GPU_ID}; then true \
             && echo "[I]: reset ${gpu_type} gpu ${GPU_ID} successfully!" \
             && true; \
            else true \
             && echo "[W]: reset ${gpu_type} gpu ${GPU_ID} failed!" \
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
