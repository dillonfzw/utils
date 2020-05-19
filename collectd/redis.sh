#! /usr/bin/env bash


declare HOSTNAME="${COLLECTD_HOSTNAME:-`hostname -f`}"
declare INTERVAL="${COLLECTD_INTERVAL:-10}"
declare REDIS_HOST="${REDIS_HOST:-localhost}"
declare REDIS_PORT="${REDIS_PORT:-26379}"
declare REDIS_PASS="${REDIS_PASS:-heig3diom7ee4ahs7wawahchaiN9choh}"


declare -a attrs=(
    # Server
    # ----------------------------------------------------------------------
    #"redis_version"  # :4.0.11
    #"redis_git_sha1"  # :00000000
    #"redis_git_dirty"  # :0
    #"redis_build_id"  # :5a87e09071dc2f93
    #"redis_mode"  # :standalone
    #"os"  # :Linux 4.4.0-116-generic x86_64
    #"arch_bits"  # :64
    #"multiplexing_api"  # :epoll
    #"atomicvar_api"  # :atomic-builtin
    #"gcc_version"  # :7.2.0
    #"process_id"  # :93481
    #"run_id"  # :278bb40f66d18218967215259795658025fd9d4b
    #"tcp_port"  # :26379
    "uptime_in_seconds"  # :11015
    #"uptime_in_days"  # :0
    #"hz"  # :10
    #"lru_clock"  # :12814615
    #"executable"  # :/home/darwin02/.conda/envs/darwin_ocr_20191122/bin/redis-server
    #"config_file"  # :/workspace/darwin-inference_newpipeline/conf/redis.conf

    # Clients
    # ----------------------------------------------------------------------
    "connected_clients"  # :155
    "client_longest_output_list"  # :0
    "client_biggest_input_buf"  # :0
    "blocked_clients"  # :5

    # Stats
    # ----------------------------------------------------------------------
    "total_connections_received"  # :186
    "total_commands_processed"  # :9887021
    "instantaneous_ops_per_sec"  # :293
    "total_net_input_bytes"  # :202458709124
    "total_net_output_bytes"  # :202023234054
    "instantaneous_input_kbps"  # :29506.40
    "instantaneous_output_kbps"  # :29499.44
    "rejected_connections"  # :0
    #"sync_full"  # :0
    #"sync_partial_ok"  # :0
    #"sync_partial_err"  # :0
    "expired_keys"  # :4793
    "expired_stale_perc"  # :0.01
    "expired_time_cap_reached_count"  # :0
    "evicted_keys"  # :13061
    "keyspace_hits"  # :24999
    "keyspace_misses"  # :9717614
    "pubsub_channels"  # :20
    "pubsub_patterns"  # :10
    "latest_fork_usec"  # :0
    "migrate_cached_sockets"  # :0
    "slave_expires_tracked_keys"  # :0
    "active_defrag_hits"  # :0
    "active_defrag_misses"  # :0
    "active_defrag_key_hits"  # :0
    "active_defrag_key_misses"  # :0

    # Memory
    # ----------------------------------------------------------------------
    "used_memory"  # :10640342624
    #"used_memory_human"  # :9.91G
    "used_memory_rss"  # :11702034432
    #"used_memory_rss_human"  # :10.90G
    "used_memory_peak"  # :10786300952
    #"used_memory_peak_human"  # :10.05G
    "used_memory_peak_perc"  # :98.65%
    "used_memory_overhead"  # :27546219
    "used_memory_startup"  # :1950480
    "used_memory_dataset"  # :10612796405
    "used_memory_dataset_perc"  # :99.76%
    "total_system_memory"  # :540624691200
    #"total_system_memory_human"  # :503.50G
    "used_memory_lua"  # :45056
    #"used_memory_lua_human"  # :44.00K
    "maxmemory"  # :10737418240
    #"maxmemory_human"  # :10.00G
    #"maxmemory_policy"  # :volatile-lru
    "mem_fragmentation_ratio"  # :1.10
    #"mem_allocator"  # :jemalloc-4.0.3
    "active_defrag_running"  # :0
    "lazyfree_pending_objects"  # :0

    # Replication
    # ----------------------------------------------------------------------
    #"role"  # :master
    "connected_slaves"  # :0
    #"master_replid"  # :be3da8cbc0dd4a5dec15f1af10dd0e9d9004a55d
    #"master_replid2"  # :0000000000000000000000000000000000000000
    "master_repl_offset"  # :0
    "second_repl_offset"  # :-1
    "repl_backlog_active"  # :0
    "repl_backlog_size"  # :1048576
    "repl_backlog_first_byte_offset"  # :0
    "repl_backlog_histlen"  # :0

    # CPU
    # ----------------------------------------------------------------------
    "used_cpu_sys"  # :499.98
    "used_cpu_user"  # :232.40
    "used_cpu_sys_children"  # :0.00
    "used_cpu_user_children"  # :0.00

    # Cluster
    # ----------------------------------------------------------------------
    #"cluster_enabled"  # :0

    # Keyspace
    # ----------------------------------------------------------------------
    "db[0-9]+"  # :keys=6585,expires=6568,avg_ttl=2743950
)
declare egrep_expr=$(echo "${attrs[@]}" | tr ' ' '\n' | sed -e 's/^/^/g' -e 's/$/:/' | xargs | tr ' ' '|')


declare sample_info='
# Server
redis_version:4.0.11
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:5a87e09071dc2f93
redis_mode:standalone
os:Linux 4.4.0-116-generic x86_64
arch_bits:64
multiplexing_api:epoll
atomicvar_api:atomic-builtin
gcc_version:7.2.0
process_id:93481
run_id:278bb40f66d18218967215259795658025fd9d4b
tcp_port:26379
uptime_in_seconds:11015
uptime_in_days:0
hz:10
lru_clock:12814615
executable:/home/darwin02/.conda/envs/darwin_ocr_20191122/bin/redis-server
config_file:/workspace/darwin-inference_newpipeline/conf/redis.conf
# >>
# Clients
connected_clients:155
client_longest_output_list:0
client_biggest_input_buf:0
blocked_clients:5

# Stats
total_connections_received:186
total_commands_processed:9887021
instantaneous_ops_per_sec:293
total_net_input_bytes:202458709124
total_net_output_bytes:202023234054
instantaneous_input_kbps:29506.40
instantaneous_output_kbps:29499.44
rejected_connections:0
sync_full:0
sync_partial_ok:0
sync_partial_err:0
expired_keys:4793
expired_stale_perc:0.01
expired_time_cap_reached_count:0
evicted_keys:13061
keyspace_hits:24999
keyspace_misses:9717614
pubsub_channels:20
pubsub_patterns:10
latest_fork_usec:0
migrate_cached_sockets:0
slave_expires_tracked_keys:0
active_defrag_hits:0
active_defrag_misses:0
active_defrag_key_hits:0
active_defrag_key_misses:0
# >>
# Memory
used_memory:10640342624
used_memory_human:9.91G
used_memory_rss:11702034432
used_memory_rss_human:10.90G
used_memory_peak:10786300952
used_memory_peak_human:10.05G
used_memory_peak_perc:98.65%
used_memory_overhead:27546219
used_memory_startup:1950480
used_memory_dataset:10612796405
used_memory_dataset_perc:99.76%
total_system_memory:540624691200
total_system_memory_human:503.50G
used_memory_lua:45056
used_memory_lua_human:44.00K
maxmemory:10737418240
maxmemory_human:10.00G
maxmemory_policy:volatile-lru
mem_fragmentation_ratio:1.10
mem_allocator:jemalloc-4.0.3
active_defrag_running:0
lazyfree_pending_objects:0

# Replication
role:master
connected_slaves:0
master_replid:be3da8cbc0dd4a5dec15f1af10dd0e9d9004a55d
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:0
second_repl_offset:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0

# CPU
used_cpu_sys:499.98
used_cpu_user:232.40
used_cpu_sys_children:0.00
used_cpu_user_children:0.00

# Cluster
cluster_enabled:0

# Keyspace
db10:keys=6585,expires=6568,avg_ttl=2743950
'


while true;
do
    info=$({
        #echo "$sample_info" | tail -n10;
        redis-cli -h $REDIS_HOST -p $REDIS_PORT ${REDIS_PASS:+-a} $REDIS_PASS info 2>/dev/null;
    } | grep -E "$egrep_expr")
    if true; then
        IFS_OLD=$IFS
        IFS=$'\n\r'
        for LINE in `echo "$info" | awk -F: '
            $1 == "#" { next; }
            NF < 2 { next; }
            $1 ~ /db[0-9]+/ {
                db = $1
                n = split($2, items, ","); 
                for (i=1; i<=n; i++) {
                    split(items[i], pair, "=")
                    print(db"_"pair[1]":"pair[2])
                }
                next;
            }
            /%$/ {
                print(substr($0, 1, length($0)-1))
                next;
            }
            { print $0; }
        '`;
        do
            IFS=$IFS_OLD
            key=`echo "$LINE" | cut -d: -f1  -s`
            val=`echo "$LINE" | cut -d: -f2- -s`

            # https://collectd.org/wiki/index.php/Plain_text_protocol#PUTVAL
            #
            # PUTVAL
            #
            # Synopsis
            # >> PUTVAL Identifier [OptionList] Valuelist
            #
            # Description
            # Submits one or more values (identified by Identifier) to the daemon which will
            # dispatch it to all its write plugins.
            #
            # The OptionList is an optional list of Options, where each option is a key-value-pair.
            # A list of currently understood options can be found below, all other options will be ignored.
            # Values that contain spaces must be quoted with double quotes.
            #
            # Valuelist is a colon-separated list of the time and the values, each either an unsigned
            # integer if the data source is of type COUNTER or ABSOLUTE(*), a signed integer if the data
            # source is of type DERIVE(*) or a double if the data source is of type GAUGE. You can submit
            # an undefined GAUGE value by using “U”. When submitting “U” to a COUNTER the behavior is undefined.
            # The time is given as epoch (i. e. standard UNIX time). You can use “N” instead of a time in
            # epoch which is interpreted as “now”.
            #
            # You can mix options and values, but the order is important: Options only effect following values,
            # so specifying an option as last field is allowed, but useless. Also, an option applies to all
            # following values, so you don’t need to re-set an option over and over again.
            #
            # (*) The ABSOLUTE and DERIVE data source types have been added in Version 4.8.
            #
            echo "PUTVAL $HOSTNAME/redis-$REDIS_PORT/$key interval=$INTERVAL N:$val"
        done
    else
        echo "Fail to get valid information from redis as below, try next interval:" >&2
        echo "$info" | sed -e 's/^/>> /g' >&2
    fi
    sleep $INTERVAL
done
