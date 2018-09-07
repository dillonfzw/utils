#! /usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#               ------------------------------------------
#               THIS SCRIPT PROVIDED AS IS WITHOUT SUPPORT
#               ------------------------------------------

# import (
#   get_env,
#   expand_user,
#   expand_vars,
#   expand_vars_i,
# )
source utils.sh
source log.sh

# cache for meta vars
declare -a _arg_keys=()
declare -a _arg_vals=()

# import cmd line arguments
for _item_ieh7ef4och in $@
do
    if [ "$_item_ieh7ef4och" = "--" ]; then
        shift
        break

    elif [ "$_item_ieh7ef4och" = "-h" -o "$_item_ieh7ef4och" = "--help" ]; then
        usage
        exit 0

    elif [ "$_item_ieh7ef4och" = "-v" -o "$_item_ieh7ef4och" = "--version" ]; then
        echo "$PROGVERSION"
        exit 0

    elif echo "$_item_ieh7ef4och" | grep -sq "^-"; then 
        shift
        continue

    elif echo "$_item_ieh7ef4och" | grep -sq "="; then
        _key_aixooNae4e=`echo "$_item_ieh7ef4och" | cut -d= -f1 -`
        _val_aixooNae4e=`echo "$_item_ieh7ef4och" | cut -d= -f2- -`
        [ -n "$_val_aixooNae4e" ] || _val_aixooNae4e=true
        if [ "$_val_aixooNae4e" = $(expand_vars "$_val_aixooNae4e") ]; then
            eval "$_key_aixooNae4e=\"$_val_aixooNae4e\""
        else
            _arg_keys+=("$_key_aixooNae4e")
            _arg_vals+=("$_val_aixooNae4e")
            log_debug "Cache meta variable \"$_key_aixooNae4\""
        fi
    else
        eval "$_item_ieh7ef4och=true"
    fi  
    shift
done
unset _item_ieh7ef4och

declare -p _arg_keys | sed -e 's/^/>> 1: /g' | log_lines debug
declare -p _arg_vals | sed -e 's/^/>> 1: /g' | log_lines debug

# cache meta DEFAULT_* vars
for _key_aixooNae4e in `set | grep "^DEFAULT_.*=" | cut -d= -f1 | sed -e 's/^DEFAULT_//g' | xargs`
do
    # dynamic append <var> to DEFAULT_<var> if undefined
    if ! declare -p $_key_aixooNae4e >/dev/null 2>&1; then
        _arg_keys+=("$_key_aixooNae4e")
        _arg_vals+=("%%{DEFAULT_${_key_aixooNae4e}}%%")
        declare -p DEFAULT_${_key_aixooNae4e} | \
        sed -e 's/^/Default variable: /g' -e "s/ DEFAULT_/ /" | \
        log_lines debug
    fi
    _key_aixooNae4e="DEFAULT_${_key_aixooNae4e}"

    # cache meta DEFAULT_*
    _val_aixooNae4e=`get_env $_key_aixooNae4e`
    if [ "$_val_aixooNae4e" = $(expand_vars "$_val_aixooNae4e") ]; then
        eval "$_key_aixooNae4e=\"$_val_aixooNae4e\""
        log_debug "Set direct1 $_key_aixooNae4e=\"$_val_aixooNae4e\""
    else
        _arg_keys+=("$_key_aixooNae4e")
        _arg_vals+=("$_val_aixooNae4e")
        unset $_key_aixooNae4e
        log_debug "Cache meta variable \"$_key_aixooNae4e\""
    fi
done

declare -p _arg_keys | sed -e 's/^/>> 2: /g' | log_lines debug
declare -p _arg_vals | sed -e 's/^/>> 2: /g' | log_lines debug

# expand meta vars recurrsively
has_expanded=true
while $has_expanded;
do
    has_expanded=false
    for _idx_aixooNae4e in ${!_arg_keys[@]}
    do
        _key_aixooNae4e=${_arg_keys[$_idx_aixooNae4e]}
        _val_aixooNae4e=$(expand_vars "${_arg_vals[$_idx_aixooNae4e]}")
        rc=$?
        log_debug "expand var $_key_aixooNae4e=$_val_aixooNae4e"
        test $rc -eq 0
        if [ $? -eq 0 ]; then
            eval "$_key_aixooNae4e=\"$_val_aixooNae4e\""
            log_debug "Set direct2 $_key_aixooNae4e=\"$_val_aixooNae4e\""
            unset _arg_keys[$_idx_aixooNae4e]
            unset _arg_vals[$_idx_aixooNae4e]
            has_expanded=true
            declare -p $_key_aixooNae4e | sed -e 's/^/Expand variable: /g' | log_lines debug
        fi
    done
done
if [ ${#_arg_keys[@]} -gt 0 ]; then
    for _idx_aixooNae4e in ${!_arg_keys[@]}
    do
        _key_aixooNae4e=${_arg_keys[$_idx_aixooNae4e]}
        _val_aixooNae4e=${_arg_vals[$_idx_aixooNae4e]}
        log_error "Fail to expand variable \"${_key_aixooNae4e}\" who has meta value of \"${_val_aixooNae4e}\""
    done
    exit 1
fi
unset has_expanded
unset _idx_aixooNae4e
unset _key_aixooNae4e
unset _val_aixooNae4e
unset _arg_keys
unset _arg_vals

## Initialize the default value for each variable in the OPTMAPS
#for _nvar_thi3ahh3eR in `set | grep "^DEFAULT_.*=" | cut -d= -f1 | sed -e 's/^DEFAULT_//g' | xargs`
#do
#    if [ -n "$_nvar_thi3ahh3eR" ] &&
#       eval "[ -n \"\$DEFAULT_$_nvar_thi3ahh3eR\" ]"; then
#        eval "\
#        if [ -z \"\$$_nvar_thi3ahh3eR\" ]; then \
#            $_nvar_thi3ahh3eR=\$DEFAULT_$_nvar_thi3ahh3eR; \
#            [ \"$_nvar_thi3ahh3eR\" != \"verbose\" ] && \
#            declare -p $_nvar_thi3ahh3eR | sed -e 's/^/Default variable: /g' | log_lines debug; \
#        fi;"
#    fi
#done
#unset _nvar_thi3ahh3eR

# hook for set_log_level
if [ -n "$LOG_LEVEL" ] && declare -f set_log_level >/dev/null; then
    set_log_level $LOG_LEVEL
fi
