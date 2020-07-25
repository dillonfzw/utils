#! /usr/bin/env bash


declare HOSTNAME="${COLLECTD_HOSTNAME:-`hostname -s`}"
declare INTERVAL="${COLLECTD_INTERVAL:-10}"
# all activate containers
# "grep -E" pattern
declare CONTAINER_NAME_PATTERNS=${CONTAINER_NAME_PATTERNS:-"*"}
#declare CONTAINER_NAME_PATTERNS=${CONTAINER_NAME_PATTERNS:-"[_-]`hostname -s`[_-].*\.[0-9]\."}


function get_timestamp() {
    date "+%s"
}
function translate_to_KiB() {
    local -a cnt=(`if [ -n "$1" ]; then echo "$1"; else cat -; fi | sed -e 's/^ *\([0-9.+-]*\)\([KMGTkmgt]\?[Ii]\?[Bb]\)/\1 \2/g' | tr 'a-z' 'A-Z'`)
    local val=${cnt[0]}
    local unt=${cnt[1]}

    if [ -z "$val" ]; then
        false
    elif [ "$unt" = "B" ]; then
        val=`echo "scale=4; $val / 1024" | bc -l`
    elif [ "$unt" = "KB" ]; then
        val=`echo "scale=4; $val / 1.024" | bc -l`
    elif [ "$unt" = "KIB" ]; then
        true
    elif [ "$unt" = "MB" ]; then
        val=`echo "scale=4; $val * 1000 / 1.024" | bc -l`
    elif [ "$unt" = "MIB" ]; then
        val=`echo "scale=4; $val * 1024" | bc -l`
    elif [ "$unt" = "GB" ]; then
        val=`echo "scale=4; $val * 1000000 / 1.024" | bc -l`
    elif [ "$unt" = "GIB" ]; then
        val=`echo "scale=4; $val * 1024 * 1024" | bc -l`
    elif [ "$unt" = "TB" ]; then
        val=`echo "scale=4; $val * 1000000000 / 1.024" | bc -l`
    elif [ "$unt" = "TIB" ]; then
        val=`echo "scale=4; $val * 1024 * 1024 * 1024" | bc -l`
    fi && \
    echo "$val" | sed -e 's/\.0\+$//g'
}


declare last_batch_beg_time=`get_timestamp`
last_batch_beg_time=`echo "scale=0; $last_batch_beg_time - $INTERVAL" | bc -l | sed -e 's/\.0\+$//g'`

declare skip_batch=false
docker stats --no-trunc --format="|{{.ID}},{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" | while read LINE;
do
    # pick the right batch to process, for others, just skip it
    if echo "$LINE" | grep -sq "^[^|]"; then
        batch_beg_time=`get_timestamp`
        time_diff=$((batch_beg_time - last_batch_beg_time))
        if [ `echo "$time_diff > $INTERVAL" | bc -l` -eq 1 ]; then
            skip_batch=false
            last_batch_beg_time=$batch_beg_time
        else
            skip_batch=true
        fi
    fi
    if $skip_batch; then continue; fi

    # purify unexpected characters in the input record which usually is the header of docker stats output
    LINE=`echo "$LINE" | col -b | sed -e 's/^.*|//g'`
    if [ -z "$LINE" ]; then continue; fi

    # log for debug only
    #echo "`date --rfc-3339=seconds`: $LINE"
    #continue

    IFS_OLD=$IFS; IFS=$','; declare -a info=($LINE); IFS=$IFS_OLD
    #declare -p info

    # CONTAINER ID,NAME,CPU %,MEM USAGE / LIMIT,MEM %,NET I/O BLOCK,I/O PIDS
    # ^^^^^^^^^^^^+^^^^+^^^^^+^^^^^^^^^^^^^^^^^+^^^^^+^^^^^^^^^^^^^+^^^^^^^^
    # declare -a info='(
    # [0]="8912d1207dc94cb52f7a16cdf0603efb228e82258efb528243523c917013ebc3"
    # [1]="dev_gpu01_cpu_xk.1.z2k8fxio8l58ji4g8bxtwdv7t"
    # [2]="17.79%"
    # [3]="5.064GiB / 64GiB"
    # [4]="7.91%"
    # [5]="9.13GB / 2.04GB"
    # [6]="1.22GB / 9.95GB"
    # [7]="131"
    # )'
    NODE_ID=${info[0]}
    NODE_Name=${info[1]}
    NODE_CPUPerc=${info[2]}
    NODE_MemUsage=${info[3]}
    NODE_MemPerc=${info[4]}
    NODE_NetIO=${info[5]}
    NODE_BlockIO=${info[6]}
    NODE_PIDs=${info[7]}

    if ! echo "$NODE_Name" | grep -sq -E "${CONTAINER_NAME_PATTERNS}"; then
        echo "[I]: Exclude unwanted container \"$NODE_Name\"" >&2
        continue
    fi

    # 把swarm的service形式的container名字，截断只保留<name>.<replica_id>
    NODE_Name=`echo "$NODE_Name" | sed -e 's/^\(.*\)\.\([0-9]\+\)\.\([a-z0-9]\{25\}\)$/\1.\2/' | tr '.' '_'`

    # 内存用量，分开为用量和上限
    NODE_MemLimit=`echo "${NODE_MemUsage}" | awk '{print $3}' | translate_to_KiB`
    NODE_MemUsage=`echo "${NODE_MemUsage}" | awk '{print $1}' | translate_to_KiB`
    # IO的数据，要分开提取成i和o
    NODE_NetIO_r=`echo "${NODE_NetIO}" | awk '{print $1}' | translate_to_KiB`
    NODE_NetIO_w=`echo "${NODE_NetIO}" | awk '{print $3}' | translate_to_KiB`
    NODE_BlockIO_r=`echo "${NODE_BlockIO}" | awk '{print $1}' | translate_to_KiB`
    NODE_BlockIO_w=`echo "${NODE_BlockIO}" | awk '{print $3}' | translate_to_KiB`
    # 百分号要去掉
    NODE_CPUPerc=`echo "${NODE_CPUPerc}" | sed -e 's/%$//g'`
    NODE_MemPerc=`echo "${NODE_MemPerc}" | sed -e 's/%$//g'`

    if true; then
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/CPUPerc interval=$INTERVAL N:${NODE_CPUPerc}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/MemPerc interval=$INTERVAL N:${NODE_MemPerc}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/MemUsage interval=$INTERVAL N:${NODE_MemUsage}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/MemLimit interval=$INTERVAL N:${NODE_MemLimit}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/NetIO_r interval=$INTERVAL N:${NODE_NetIO_r}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/NetIO_w interval=$INTERVAL N:${NODE_NetIO_w}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/BlockIO_r interval=$INTERVAL N:${NODE_BlockIO_r}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/BlockIO_w interval=$INTERVAL N:${NODE_BlockIO_w}"
        echo "PUTVAL $HOSTNAME/container_${NODE_Name}/PIDs interval=$INTERVAL N:${NODE_PIDs}"
    fi | sed -e 's/\.0\+$//g'
done
