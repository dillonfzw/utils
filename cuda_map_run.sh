#! /usr/bin/env bash


_CUDA_DEVICES=$1; shift
_WRAPPED_CMD=$1; shift

TS=`date "+%Y%m%d_%H%M"`


#
# prepare help usage
#
function help() {
    echo "Usage: $0 0,2,3,4 /foo/bar/start.sh parm1 parm2 parm3" >&2
    echo "..." >&2
    echo "" >&2
    echo "$ ls logs/log.*.txt" >&2
    echo "logs/log.start-2023XXXX_XXXX-d0.txt" >&2
    echo "logs/log.start-2023XXXX_XXXX-d2.txt" >&2
    echo "logs/log.start-2023XXXX_XXXX-d3.txt" >&2
    echo "logs/log.start-2023XXXX_XXXX-d4.txt" >&2
    exit 0
}
if [ -z "${_WRAPPED_CMD}" ]; then help; exit 0; fi


#
# prepare house cleaner
#
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


#
# run workloads in target cuda devices
#
[ -d logs ] || mkdir logs
for _CUDA_DEVICE in `echo ${_CUDA_DEVICES} | tr ',' ' '`
do
    env CUDA_VISIBLE_DEVICES=${_CUDA_DEVICE} \
    ${_WRAPPED_CMD} $@ \
    >logs/log.${_WRAPPED_CMD##*/}-${TS}-d${_CUDA_DEVICE}.txt 2>&1 &

    G_task_pids+=($!)
done


#
# show aggregated output
#
tail -F logs/log.${_WRAPPED_CMD##*/}-${TS}-d*.txt &
G_task_wait=$!


#
# wait all tasks' finish
#
wait ${G_task_pids[@]}


#
# terminate output
#
kill -SIGTERM ${G_task_wait}
exit 0
