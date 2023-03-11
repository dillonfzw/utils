#! /usr/bin/env bash


_CUDA_DEVICES=$1; shift
_WRAPPED_CMD=$1; shift

TS=`date "+%Y%m%d_%H%M"`


declare -a G_task_pids=()
function finish() {
    if [ ${#G_task_pids[@]} -eq 0 ]; then return; fi
    echo "[N]: House clean when exiting..." >&2
    declare -p G_task_pids

    echo "[I]: Interrupting child tasks..." >&2
    kill -SIGINT ${G_task_pids[@]}
    sleep 2
    echo "[I]: Terminating child tasks..." >&2
    kill -SIGTERM ${G_task_pids[@]}
}
trap finish SIGTERM SIGINT



[ -d logs ] || mkdir logs
for _CUDA_DEVICE in `echo ${_CUDA_DEVICES} | tr ',' ' '`
do
    env CUDA_VISIBLE_DEVICES=${_CUDA_DEVICE} \
    ${_WRAPPED_CMD} $@ \
    >logs/log.${_WRAPPED_CMD}-${TS}-d${_CUDA_DEVICE}.txt 2>&1 &

    G_task_pids+=($!)
done


wait
