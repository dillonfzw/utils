#! /bin/bash

# declare a noop msgutil_r, 
# - if no log server was defined.
# - if no msgutil_r imported from xcatlib.sh
if ! declare -F msgutil_r &>/dev/null || \
   [ -z "$logserver" ]; then
    function msgutil_r { true; }
fi


# https://en.wikipedia.org/wiki/Syslog#Severity_level
declare -a LOG_LEVELS
declare -a LOG_PREFIXES
declare -a LOG_LEVELS_RMAP
LOG_LEVELS=(  [0]="emerg" [1]="alert" [2]="crit" [3]="error" [4]="warn" [5]="notice" [6]="info" [7]="debug")
LOG_PREFIXES=([0]="M"     [1]="A"     [2]="C"    [3]="E"     [4]="W"    [5]="N"      [6]="I"    [7]="D")
# convert log level to its corresponding number
function __logLevelToNum() {
    declare levelName=$1
    declare levelNameSum=`echo "${levelName}" | sum | cut -d' ' -f1 | sed -e 's/^0*//g'`
    # hidden set function
    if [ -n "$2" ]; then LOG_LEVELS_RMAP[$levelNameSum]=$2; fi
    declare r=${LOG_LEVELS_RMAP[$levelNameSum]}
    echo "$r"
    test -n "$r"
}
# declare core log wrapper functions
declare -F log_lines &>/dev/null || \
function log_lines {
    declare levelName=${1:-"info"}; shift
    declare levelNum

    # refine log level name and its number
    if echo "$levelName" | grep -sq "^[0-9]\+"; then
        levelNum=${levelName}
        levelName=${LOG_LEVELS[$levelNum]}
    else
        levelNum=`__logLevelToNum ${levelName}`
    fi && \

    # make sure requested log level higher than define log level
    #set | grep -E "^__logLevelNum|^levelNum" && \
    if [ $__logLevelNum -lt ${levelNum} ]; then
        return 0
    fi && \

    declare levelPrefix="[${LOG_PREFIXES[$levelNum]}]:" && \

    declare line=$@ && \
    if [ -n "$line" ]; then
        echo "$levelPrefix $line" >&2
        msgutil_r $logserver $levelName "$levelPrefix $line"
    else
        while read line;
        do
            echo "$levelPrefix $line" >&2
            msgutil_r $logserver $levelName "$levelPrefix $line"
        done
    fi
}
function set_log_level() {
    __logLevelNum=`__logLevelToNum $1`
}
function get_log_level() {
    echo ${LOG_LEVELS[$__logLevelNum]}
}
declare -a __logLevelNumStack
function push_log_level() {
    declare levelName=$1
    declare levelNum=`__logLevelToNum $levelName`
    # cd `pwd` is just waste of time!
    if [ "$__logLevelNum" = "$levelNum" ]; then return 0; fi
    # get the latest log level in the stack
    declare top=${#__logLevelNumStack[@]}
    declare latestLevelNum=""
    if [ $top -gt 0 ]; then
        latestLevelNum=${__logLevelNumStack[$((top-1))]}
    fi
    # push current level to stack
    __logLevelNumStack[$top]=$__logLevelNum
    # apply log level
    set_log_level $levelName && \
    echo "${__logLevelNumStack[@]}"
}
function pop_log_level() {
    declare top=${#__logLevelNumStack[@]}
    declare levelNum=""
    if [ "$top" -gt 0 ]; then
        ((top-=1))
        levelNum=${__logLevelNumStack[$top]}
        unset __logLevelNumStack[$top]
    fi
    if [ -n "$levelNum" ]; then
        declare levelName=${LOG_LEVELS[$levelNum]} && \
        set_log_level $levelName && \
        echo "${__logLevelNumStack[@]}"
    else
        false
    fi
}
declare icnt=0
declare idx=0
while [ $icnt -lt ${#LOG_LEVELS[@]} ];
do
    if [ -n "${LOG_LEVELS[$idx]}" ]; then
        declare levelName=${LOG_LEVELS[$idx]}
        declare levelNum=$idx

        # register log levels by setting revert map of level name to its index
        __logLevelToNum $levelName $levelNum >/dev/null

        # declare helper function
        declare _cmd_yaing4ai4i='declare -F log_'${levelName}' &>/dev/null || function log_'${levelName}' { if [ -n "$*" ]; then log_lines '${levelNum}' "$@"; fi; }'
        eval "$_cmd_yaing4ai4i"
        unset _cmd_yaing4ai4i
        ((icnt+=1))
    fi
    ((idx+=1))
done
unset icnt
unset idx

# set verbose level to info
# NOTE: this must be called after log levels had been registered
declare __logLevelNum=
set_log_level ${LOG_LEVEL:-${DEFAULT_LOG_LEVEL:-info}}
