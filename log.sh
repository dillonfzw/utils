#! /bin/bash

# declare a noop msgutil_r, 
# - if no log server was defined.
# - if no msgutil_r imported from xcatlib.sh
if ! declare -F msgutil_r &>/dev/null || \
   [ -z "$logserver" ]; then
    function msgutil_r { true; }
fi

# declare log wrapper functions
declare _typePrefix_info="[I]:"
declare _typePrefix_debug="[D]:"
declare _typePrefix_warn="[W]:"
declare _typePrefix_error="[E]:"

declare -F log_lines &>/dev/null || \
function log_lines {
    declare logType=${1:-"info"}; shift
    eval "declare typePrefix=\$_typePrefix_$logType"

    declare line=$@
    if [ -n "$line" ]; then
        echo "$typePrefix $line" >&2
        msgutil_r $logserver $logType "$typePrefix $line"
    else
        while read line;
        do
            echo "$typePrefix $line" >&2
            msgutil_r $logserver $logType "$typePrefix $line"
        done
    fi
}
declare -F log_error &>/dev/null || function log_error { log_lines error "$@"; }
declare -F log_warn &>/dev/null || function log_warn { log_lines warn "$@"; }
declare -F log_info &>/dev/null || function log_info { log_lines info "$@"; }
declare -F log_debug &>/dev/null || function log_debug { log_lines debug "$@"; }
