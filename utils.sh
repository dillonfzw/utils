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

# --------------------------------------------------------------------------------
# Typical usage:
# $ bash ./utils.sh cmd=<function_name> -- arg1 arg2 arg3 ...
#
# examples:
# 1) list all cmds
# $ bash ./utils.sh cmd=usage
#
#
# 2) run unit test
# # run all tests
# $ bash ./utils.sh cmd=run_unit_test
#
# # run a list of specific tests
# $ bash ./utils.sh cmd=run_unit_test -- test_tac test_shuf
#
#
# 3) 把本工具库做成内嵌代码段，放到其他脚本
# $ bash ./utils.sh cmd=enc_self_b64_gz | tee -a 1.sh
# # 试验一下，看看内嵌代码段能否展开
# $ bash -x ./1.sh
# --------------------------------------------------------------------------------


PROG_CLI=${PROG_CLI:-$0}
if echo "$PROG_CLI" | grep -sq "^\/" && command -v ${PROG_CLI} >/dev/null 2>&1; then
    PROG_CLI=`command -v $PROG_CLI`
fi
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}
if [ "${PROG_DIR}" == "${PROG_NAME}" ]; then
    PROG_DIR=.
fi



# ------------------ cut here beg Aeth4Aechoo7ca7aez4eesh3eigeitho -------------
#-------------------------------------------------------------------------------
# begin of utility functions
#
`command -v tac >/dev/null 2>&1` ||
function tac() {
    tail -r $@
}
function __test_tac() {
    local err_cnt=0

    #
    # osx will have tac be redirected to own own function
    #
    ! $is_osx || \
    { test `type -t tac` = "function"; } || { ((err_cnt+=1)); log_error "Fail sub-case 1"; }

    { test "`echo '1
2
3' | tac`" = '3
2
1'; } || {
        ((err_cnt+=1)); log_error "Fail sub-case 2";
    }

    test $err_cnt -eq 0
}
`command -v shuf >/dev/null 2>&1` ||
function shuf() {
    #
    # support only "-e"
    #
    if [ "$1" = "-e" ]; then
        shift
        while [ ${#@} -gt 0 ]; do echo "$1"; shift; done
    else
        cat -
    fi |
    while read LINE; do echo "$RANDOM $LINE"; done | \
    sort -t' ' -k1 -n | cut -d' ' -f2-
}
function __test_shuf() {
    local err_cnt=0

    #
    # osx will have shuf redirected to our own function
    #
    ! $is_osx || \
    { declare -F | grep -sqw "shuf"; } || { ((err_cnt+=1)); log_error "Fail sub-case 1"; }

    line0=`echo "1 2 3 4 5" | tr ' ' '\n'`
    line1=`echo "$line0" | shuf`

    #
    # verify the functionality when get input from stdin
    #
    echo "$line0" | sed -e 's/^/[line0] >> /g' | log_lines debug
    echo "$line1" | sed -e 's/^/[line1] >> /g' | log_lines debug
    line1_s=`echo "$line1" | sort -n`
    [ `echo "$line1" | awk "END{print NR}"` -eq 5 \
        -a "$line1" != "$line0" \
        -a "$line1_s" = "$line0" \
    ] || { ((err_cnt+=1)); log_error "Fail sub-case 2"; }

    #
    # two shuf have two different order to validate the random takes effect.
    #
    line2=`shuf -e $line0`
    echo "$line2" | sed -e 's/^/[line2] >> /g' | log_lines debug
    line2_s=`echo "$line2" | sort -n`
    [ "$line2" != "$line1" \
        -a "$line2" != "$line0" \
        -a `echo "$line2" | awk "END{print NR}"` -eq 5 \
        -a "$line2_s" = "$line0" \
    ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 3";
    }

    test $err_cnt -eq 0
}
function get_env() {
    eval "echo \${$1}" 2>/dev/null
}
function is_running_in_docker() {
    mount | grep 'on / type' | grep -sqE '(overlay|aufs)' || \
    grep -sqE '^1:.+(docker|lxc|kubepods)' /proc/self/cgroup || \
    # * https://stackoverflow.com/questions/23513045/how-to-check-if-a-process-is-running-inside-docker-container
    awk -F/ '$2 == "docker"' /proc/self/cgroup 2>/dev/null | read || \
    # * 12:blkio:/system.slice/docker-ce36ac066645880e2512f2a4ef5638d34e7af1d2f47a9972146149e15a094a76.scope
    awk -F/ '$3 ~ /^docker-/' /proc/self/cgroup 2>/dev/null | read || \
    # * https://stackoverflow.com/questions/20010199/how-to-determine-if-a-process-runs-inside-lxc-docker
    test -f /.dockerenv
}
function declare_f() {
    declare -f $@
}
function declare_p() {
    declare -p $@
}
function declare_p_val() {
    local var c length pos _l_shift _r_shift
    local G_expr_bin=${G_expr_bin:-expr}
    for var;
    do
        declare -p $var 2>/dev/null | \
            sed -e "1s/^.*$var=//" | \
            sed -e '1s/^"//' -e '$s/"$//' | \
            sed -e "1s/^'//" -e "\$s/'$//" | \
            cat -
    done
}
function __test_declare_p_val() {
    local err_cnt=0

    # 测试数值变量
    local a=1237
    local b=`declare_p_val a`
    [ $a -eq $b ] || { ((err_cnt+=1)); log_error "fail sub-test 1: `declare -p b`"; }

    # 测试字符串变量
    local a="hello world"
    local b=`declare_p_val a`
    [ "$a" == "$b" ] || { ((err_cnt+=1)); log_error "fail sub-test 2: `declare -p b`"; }

    # 测试多行文本
    local a="$(</etc/hosts)"
    local b=`declare_p_val a`
    [ "$a" == "$b" ] || { ((err_cnt+=1)); log_error "fail sub-test 3: `declare -p b`"; }

    # 测试简单数组
    local -a a=(1 2)
    local -a b=`declare_p_val a`
    array_equal a[@] b[@] || { ((err_cnt+=1)); log_error "fail sub-test 4:
    |`declare_p_val a`|
    |`declare -p a`|
    |`declare -p b`|"; }

    # 测试复杂数组
    local -a a=(1 2 "hello" 5.88 "$(</etc/hosts)")
    local -a b=`declare_p_val a`
    array_equal a[@] b[@] || { ((err_cnt+=1)); log_error "fail sub-test 5: `declare -p b`"; }

    test $err_cnt -eq 0
}
function upper() {
    tr '[a-z]' '[A-Z]'
}
function __test_upper() {
    local err_cnt=0
    [ `echo "AaBbCc.2#4%" | upper` = "AABBCC.2#4%" ] || { ((err_cnt+=1)); log_error "fail sub-test 1"; }
    test $err_cnt -eq 0
}
function lower() {
    tr '[A-Z]' '[a-z]'
}
function __test_lower() {
    local err_cnt=0
    [ `echo "AaBbCc.2#4%" | lower` = "aabbcc.2#4%" ] || { ((err_cnt+=1)); log_error "fail sub-test 1"; }
    test $err_cnt -eq 0
}
function dedup() {
    # deduplication: sort and unique while keeping order
    tr ':' '\n' | sed -e '/^ *$/d' | nl -nln -w1 -s'|' | sort -t'|' -k2,2 -u | sort -t'|' -k1 -n | cut -d'|' -f2 | tr '\n' ':' | tr -s ':' | sed -e 's/^:\(.*\):/\1/g' -e 's/:$//g'
}
function __test_dedup() {
    local err_cnt=0
    local r=`echo ":b:a:c:b:a:d:" | dedup`
    [ "x$r" = "xb:a:c:d" ] || { ((err_cnt+=1)); log_error "fail sub-test 1: \"${r}\""; }
    test $err_cnt -eq 0
}
function run_unit_test() {
    local -a _NC3v_all_unit_test_cases=(`declare -F | awk '{print $3}' | grep "^__test" | sed -e 's/^__//' | xargs`)

    local -a _NC3v_target_cases
    if [ "$1" = "@all" -o $# -eq 0 ]; then
        _NC3v_target_cases=(${_NC3v_all_unit_test_cases[@]})
    else
        _NC3v_target_cases=($@)
    fi

    local i f_case cnt_fail
    ((cnt_fail=0))
    for i in ${!_NC3v_target_cases[@]}
    do
        f_case=${_NC3v_target_cases[$i]}
        log_debug "Test $((i+1))/${#_NC3v_target_cases[@]} \"$f_case\"..."
        if __$f_case; then
            log_info "Test $((i+1))/${#_NC3v_target_cases[@]} \"$f_case\"... succ"
        else
            log_error "Test $((i+1))/${#_NC3v_target_cases[@]} \"$f_case\"... fail"
            ((cnt_fail+=1))
        fi
    done
    if [ ${cnt_fail} -gt 0 ]; then
        echo -e "\n\nRun ${#_NC3v_target_cases[@]} case(s) with $cnt_fail failed.\n" | log_lines error
    else
        echo -e "\n\nRun ${#_NC3v_target_cases[@]} case(s) with all succ.\n" | log_lines info
    fi
}
function _fail_unit_test() {
    log_error "Fail shell unit case \"${FUNCNAME[1]}\" $@"
}
function __test__fail_unit_test {
    local err_cnt=0
    _fail_unit_test "oni4aeng" 2>&1 | grep -sqF "Fail shell unit case \"${FUNCNAME[0]}\" oni4aeng" || {
        ((err_cnt+=1)); log_error "Fail shell unit case \"${FUNCNAME[0]}\" sub-case 1";
    }
    test $err_cnt -eq 0
}
function chain_op() {
    local op
    for op;
    do
        #log_debug "[chain_op] >> $op"
        $op || return
    done
}
function __test_chain_op() {
    function r_9() { return 9; }
    function r_3() { return 3; }

    local err_cnt=0

    chain_op true r_9 r_3
    [ $? -eq 9 ] || { ((err_cnt+=1)); log_error "Fail sub-test 1"; }

    chain_op true true
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "Fail sub-test 2"; }

    chain_op
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "Fail sub-test 3"; }

    test $err_cnt -eq 0
}
function not_() {
    local op=$1; shift
    if $op $@; then false; else true; fi
}
function __test_not_() {
    local err_cnt=0

    # basic test
    not_ true && { ((err_cnt+=1)); log_error "Fail not_ true"; }
    not_ false || { ((err_cnt+=1)); log_error "Fail not_ false"; }

    # test op with parameter
    not_ grep -sqx '12398fdklaef90823p;' /etc/hosts || { ((err_cnt+=1)); log_error "Fail not_ false"; }

    test $err_cnt -eq 0
}
function contains() {
    # reference from https://stackoverflow.com/a/8574392
    local -a _wgJ3_container=("${!1}")
    local match=$2

    # log for debug
    #declare -p _wgJ3_container | sed -e 's/^/[c]>> /g' | log_lines debug
    #declare -p match | sed -e 's/^/[m]>> /g' | log_lines debug

    local i
    for i in ${!_wgJ3_container[@]}
    do
        local e="${_wgJ3_container[$i]}"

        # log for debug
        #declare -p e | sed -e 's/^/[e]>> /g' | log_lines debug

        if [[ "$e" == "${match}" ]]; then
            return 0
        fi
    done
    return 1
}
function __test_contains() {
    local err_cnt=0
    local -a a=("hello" "world" "fox")
    local -a empty=()

    hosts=$(</etc/hosts)
    n_lines=`echo "$hosts" | wc -l | awk '{print $1}'`
    [ $n_lines -gt 0 ] || { ((err_cnt+=1)); log_error "fail pre-assert 0"; }

    a+=("$hosts")

    contains a[@] "hello" || { ((err_cnt+=1)); log_error "fail normal exist item sub-test 1"; }

    contains a[@] "he" && { ((err_cnt+=1)); log_error "fail normal not-exist item sub-test 2"; }
    contains a[@] "" && { ((err_cnt+=1)); log_error "fail normal null item sub-test 2"; }

    contains a[@] "$hosts" || { ((err_cnt+=1)); log_error "fail complex item sub-test 3"; }

    contains empty[@] "he" && { ((err_cnt+=1)); log_error "fail test empty sub-test 4"; }
    contains empty[@] "" && { ((err_cnt+=1)); log_error "fail test empty sub-test 4"; }

    test $err_cnt -eq 0
}
function array_equal() {
    # test if two array are exactly equal
    #
    # :param arr_a:
    # :param arr_b:
    # :return: bool
    local -a _oV7u_arr_a=("${!1}")
    local -a _oV7u_arr_b=("${!2}")

    # log for debug
    #declare -p _oV7u_arr_a | sed -e 's/^/[arr_eq]>> /g' | log_lines debug
    #declare -p _oV7u_arr_b | sed -e 's/^/[arr_eq]>> /g' | log_lines debug

    # compare length
    if [ ${#_oV7u_arr_a[@]} -ne ${#_oV7u_arr_b[@]} ]; then
        return 1
    fi

    # element per element compare
    local i a b
    for i in ${!_oV7u_arr_a[@]}
    do
        a="${_oV7u_arr_a[$i]}"
        b="${_oV7u_arr_b[$i]}"
        if [ "$a" != "$b" ]; then return 1; fi
    done
    return 0
}
function __test_array_equal() {
    local err_cnt=0
    local -a a=(1 "2 a" 3)
    local -a b=(1 2 a 3)
    local -a empty=()

    array_equal a[@] b[@] || { ((err_cnt+=1)); log_error "fail normal positive sub-test 1"; }

    b=(3 3)
    array_equal a[@] b[@] && { ((err_cnt+=1)); log_error "fail normal negative sub-test 2"; }

    array_equal empty[@] empty[@] || { ((err_cnt+=1)); log_error "fail empty sub-test 3"; }

    array_equal a[@] empty[@] && { ((err_cnt+=1)); log_error "fail empty vs. non-empty sub-test 4"; }
    array_equal empty[@] a[@] && { ((err_cnt+=1)); log_error "fail no-empty vs. empty sub-test 5"; }

    test $err_cnt -eq 0
}
function array_concat() {
    # concatenate two array
    #
    # :param arr_a:
    # :param arr_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _Ly3e_arr_a=("${!1}")
    local -a _Ly3e_arr_b=("${!2}")

    # log for debug
    #declare -p _Ly3e_arr_a | sed -e 's/^/[arr_concat]>> /g' | log_lines debug
    #declare -p _Ly3e_arr_b | sed -e 's/^/[arr_concat]>> /g' | log_lines debug

    local i e
    for i in ${!_Ly3e_arr_b[@]}
    do
        e="${_Ly3e_arr_b[$i]}"
        _Ly3e_arr_a+=("$e")
    done
    declare_p_val _Ly3e_arr_a
}
function __test_array_concat() {
    local err_cnt=0
    local -a a=(1 2 3)
    local -a b=(11 2 33)
    local -a empty=()
    local -a r_truth=(1 2 3 11 2 33)

    local -a r=`array_concat a[@] b[@]`
    array_equal r[@] r_truth[@] || { ((err_cnt+=1)); log_error "fail normal test 1"; }

    local -a r=`array_concat a[@] empty[@]`
    array_equal a[@] r[@] || { ((err_cnt+=1)); log_error "fail valid + empty test 1"; }

    local -a r=`array_concat empty[@] a[@]`
    array_equal a[@] r[@] || { ((err_cnt+=1)); log_error "fail empty + valid test 1"; }

    test $err_cnt -eq 0
}
function array_map() {
    # map array elements
    #
    # :param arr_a:
    # :param map op/functor per element
    # :return: an array with the format of "local -p"'s value syntax
    local -a _iYf3_arr_i=("${!1}")
    local _iYf3_map_op=${2:-true}
    local -a _iYf3_arr_o=()

    # log for debug
    #declare -p _iYf3_arr_a | sed -e 's/^/[arr_map]>> /g' | log_lines debug

    local i
    for i in ${!_iYf3_arr_i[@]}
    do true \
     && local e="${_iYf3_arr_i[$i]}" \
     && local _e \
     && { _e=$(${_iYf3_map_op} "${e}") || break; } \
     && _iYf3_arr_o+=("$_e") \
     && true;
    done

    declare_p_val _iYf3_arr_o
    test ${#_iYf3_arr_i[@]} -eq ${#_iYf3_arr_o[@]}
}
function __test_array_map() {
    local err_cnt=0
    local -a a=(1 2 3)
    local -a b=(11 2 33)
    local -a empty=()
    local -a r_truth=(1 2 3 11 2 33)

    #
    # echo
    local -a r=`array_map a[@] echo`
    array_equal r[@] a[@] || { ((err_cnt+=1)); log_error "fail normal test 1"; }
    unset r

    #
    # normal oneline record
    local -a txt1=()
    txt1+=("who are you")
    txt1+=("hello
    world")
    txt1+=("where are you")

    local -a txt1_truth=("WHO ARE YOU" "HELLO
    WORLD"
    "WHERE ARE YOU")
    function map_op1() { echo "$@" | upper; }
    local -a r=`array_map txt1[@] map_op1`
    #declare -p r
    array_equal r[@] txt1_truth[@] || { ((err_cnt+=1)); log_error "Fail case 2"; declare -p r; }
    unset r

    #
    # empty output
    function map_op2() { true; }
    local -a txt2_truth=("" "" "")
    local -a r=`array_map txt1[@] map_op2`
    #declare -p r
    array_equal r[@] txt2_truth[@] || { ((err_cnt+=1)); log_error "Fail case 3"; declare -p r; }
    unset r

    #
    # map has failure
    function map_op2() { if echo "$@" | grep -sq hello; then false; else echo "$@"; fi }
    local -a txt2_truth=("who are you")
    _c=$(array_map txt1[@] map_op2) && { ((err_cnt+=1)); log_error "Fail case 4"; declare -p r; }
    local -a r=$_c
    #declare -p r _c
    array_equal r[@] txt2_truth[@] || { ((err_cnt+=1)); log_error "Fail case 4"; declare -p r; }
    unset r

    test $err_cnt -eq 0
}
function array_filter() {
    # filter array elements
    #
    # :param arr_a:
    # :param filter op/functor per element
    # :return: an array with the format of "local -p"'s value syntax
    local -a _iYf3_arr_i=("${!1}")
    local _iYf3_filter_op=${2:-true}
    local -a _iYf3_arr_o=()

    # log for debug
    #declare -p _iYf3_arr_a | sed -e 's/^/[arr_filter]>> /g' | log_lines debug

    local i
    for i in ${!_iYf3_arr_i[@]}
    do true \
     && local e="${_iYf3_arr_i[$i]}" \
     && if ${_iYf3_filter_op} "${e}" >/dev/null; then true \
         && _iYf3_arr_o+=("$e") \
         && true;
        fi \
     && true;
    done
    declare_p_val _iYf3_arr_o
}
function __test_array_filter() {
    local err_cnt=0
    local -a a=(1 2 3)
    local -a b=(11 2 33)
    local -a empty=()
    local -a r_truth=(1 2 3 11 2 33)

    # default op is "pass all"
    local -a r=`array_filter a[@]`
    array_equal r[@] a[@] || { ((err_cnt+=1)); log_error "fail normal test 1"; }

    # "deny all" scenario
    local -a r=`array_filter a[@] false`
    array_equal r[@] empty[@] || { ((err_cnt+=1)); log_error "fail normal test 2"; }

    # normal oneline record
    local -a txt1=()
    txt1+=("who are you")
    txt1+=("hello
    world")
    txt1+=("where are you")

    function filter_op1() { echo "$@" | grep -si "you"; }
    local -a txt1_truth=("who are you" "where are you")
    local -a r=`array_filter txt1[@] filter_op1`
    array_equal r[@] txt1_truth[@] || { ((err_cnt+=1)); log_error "Fail case 3"; declare -p r; }

    # multi line record
    function filter_op2() { echo "$@" | grep -si -E "hello|who"; }
    local -a txt2_truth=("who are you" "hello
    world")
    local -a r=`array_filter txt1[@] filter_op2`
    array_equal r[@] txt2_truth[@] || { ((err_cnt+=1)); log_error "Fail case 4"; declare -p r; }

    test $err_cnt -eq 0
}
function set_rize() {
    # convert an array to set by remove its duplicate elements
    #
    # :param arr_a:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _Ez9X_arr_a=("${!1}")

    # log for debug
    #declare -p arr_a | sed -e 's/^/[c]>> /g' | log_lines debug

    local -a _Ez9X_r=()
    local i e
    for i in ${!_Ez9X_arr_a[@]}
    do
        e="${_Ez9X_arr_a[$i]}"
        if ! contains _Ez9X_r[@] "$e"; then
            _Ez9X_r+=("$e")
        fi
    done
    declare_p_val _Ez9X_r
}
function __test_set_rize() {
    local err_cnt=0
    local -a empty=()

    local -a a=(1 2 1 3)
    local -a r_truth=(1 2 3)
    local -a r=`set_rize a[@]`
    array_equal r[@] r_truth[@] || { ((err_cnt+=1)); log_error "fail set has multiple unique elements sub-test 1"; }

    local -a a=(1 1 1)
    local -a r_truth=(1)
    local -a r=`set_rize a[@]`
    array_equal r[@] r_truth[@] || { ((err_cnt+=1)); log_error "fail set has one unique elements sub-test 2"; }

    local -a a=()
    local -a r=`set_rize a[@]`
    array_equal r[@] empty[@] || { ((err_cnt+=1)); log_error "fail set-rize empty array sub-test 3"; }
    array_equal empty[@] r[@] || { ((err_cnt+=1)); log_error "fail set-rize empty array sub-test 4"; }

    test $err_cnt -eq 0
}
function set_equal() {
    # test if two set are equal
    #
    # NOTE: you have to ensure two inputs are already set-rized.
    #
    # :param set_a:
    # :param set_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _d3Ki_set_a=("${!1}")
    local -a _d3Ki_set_b=("${!2}")

    # log for debug
    #declare -p _d3Ki_set_a | sed -e 's/^/[set_equal] >> /g' | log_lines debug
    #declare -p _d3Ki_set_b | sed -e 's/^/[set_equal] >> /g' | log_lines debug

    # compare length
    if [ ${#_d3Ki_set_a[@]} -ne ${#_d3Ki_set_b[@]} ]; then
        return 1
    fi

    # element per element compare
    local i e
    for i in ${!_d3Ki_set_a[@]}
    do
        e="${_d3Ki_set_a[$i]}"
        if ! contains _d3Ki_set_b[@] "$e"; then return 1; fi
    done
    return 0
}
function __test_set_equal() {
    local err_cnt=0
    local -a a=(1 2 3)
    local -a b=(1 2 3)
    local -a empty=()

    set_equal a[@] b[@] || { ((err_cnt+=1)); log_error "fail normal positive sub-test 1"; }

    b=(3 2)
    set_equal a[@] b[@] && { ((err_cnt+=1)); log_error "fail normal negative sub-test 2"; }

    set_equal empty[@] empty[@] || { ((err_cnt+=1)); log_error "fail empty sub-test 3"; }

    set_equal a[@] empty[@] && { ((err_cnt+=1)); log_error "fail empty vs. non-empty sub-test 4"; }
    set_equal empty[@] a[@] && { ((err_cnt+=1)); log_error "fail no-empty vs. empty sub-test 5"; }

    local -a b=(1 1 2 3)
    set_equal a[@] b[@] && { ((err_cnt+=1)); log_error "fail a vs. non-set-rized b sub-test 6"; }
    set_equal b[@] a[@] && { ((err_cnt+=1)); log_error "fail non-set-rized b vs. a sub-test 7"; }

    test $err_cnt -eq 0
}
function set_equal_strict() {
    # test if two set are equal after enforcing a set-rize
    #
    # :param set_a:
    # :param set_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _HF7R_set_a=("${!1}")
    local -a _HF7R_set_b=("${!2}")

    local -a __HF7R_set_a=`set_rize _HF7R_set_a[@]`
    local -a __HF7R_set_b=`set_rize _HF7R_set_b[@]`
    set_equal __HF7R_set_a[@] __HF7R_set_b[@]
}
function __test_set_equal_strict() {
    local err_cnt=0
    local -a a=(1 2 1 3)
    local -a b=(1 2 3 1 2)
    local -a empty=()

    set_equal_strict a[@] b[@] || { ((err_cnt+=1)); log_error "fail normal positive sub-test 1"; }
    set_equal_strict empty[@] empty[@] || { ((err_cnt+=1)); log_error "fail empty sub-test 3"; }

    test $err_cnt -eq 0
}
function set_intersection() {
    # calculate the intersction of two input sets
    #
    # :param set_a:
    # :param set_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _oLp4_set_a=("${!1}")
    local -a _oLp4_set_b=("${!2}")
    local -a _oLp4_set_r=()

    # log for debug
    #declare -p _oLp4_set_a | log_lines debug
    #declare -p _oLp4_set_b | log_lines debug

    local i e
    for i in ${!_oLp4_set_a[@]}
    do
        e="${_oLp4_set_a[$i]}"
        if contains _oLp4_set_b[@] "$e"; then _oLp4_set_r+=("$e"); fi
    done
    declare_p_val _oLp4_set_r
}
function __test_set_intersection() {
    local err_cnt=0
    local -a a=(1 2 3 4)
    local -a b=(3 2)
    local -a c=(33)
    local -a empty=()

    local -a r_t=(2 3)
    local -a r=`set_intersection a[@] b[@]`
    set_equal r_t[@] r[@] || { ((err_cnt+=1)); log_error "fail a & b intersection 1"; }

    local -a r_t=(3 2)
    local -a r=`set_intersection b[@] a[@]`
    set_equal r_t[@] r[@] || { ((err_cnt+=1)); log_error "fail b & a intersection 2"; }

    local -a r=`set_intersection b[@] c[@]`
    set_equal empty[@] r[@] || { ((err_cnt+=1)); log_error "fail isolate intersection 3"; }

    test $err_cnt -eq 0
}
function set_difference() {
    # calculate the difference of set A from B
    #
    # :param set_a:
    # :param set_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _YNj3_set_a=("${!1}")
    local -a _YNj3_set_b=("${!2}")
    local -a _YNj3_set_r=()

    # log for debug
    #declare -p _YNj3_set_a | sed -e 's/^/[set_diff] >> /g' | log_lines debug
    #declare -p _YNj3_set_b | sed -e 's/^/[set_diff] >> /g' | log_lines debug

    local i
    for i in ${!_YNj3_set_a[@]}
    do
        local e="${_YNj3_set_a[$i]}"
        if not_ contains _YNj3_set_b[@] "$e"; then _YNj3_set_r+=("$e"); fi
    done
    declare_p_val _YNj3_set_r
}
function __test_set_difference() {
    local err_cnt=0
    local -a empty=()

    local -a a=(1 2 3 4)
    local -a b=(3 2)
    local -a r_t=(1 4)
    local -a r=`set_difference a[@] b[@]`
    set_equal r[@] r_t[@] || { ((err_cnt+=1)); log_error "fail num of elements in set_intersection sub-test 1"; }

    local -a a=(1 2 3 4)
    local -a b=(33 22)
    local -a r=`set_difference a[@] b[@]`
    set_equal r[@] a[@] || { ((err_cnt+=1)); log_error "fail isolate set & in set_intersection sub-test 2"; }

    local -a a=(2 4)
    local -a b=(3 2 6 4)
    local -a r=`set_difference a[@] b[@]`
    set_equal r[@] empty[@] || { ((err_cnt+=1)); log_error "fail contained set & in set_intersection sub-test 3"; }

    local -a r=`set_difference empty[@] empty[@]`
    set_equal r[@] empty[@] || { ((err_cnt+=1)); log_error "fail empty sets & sub-test 4"; }

    test $err_cnt -eq 0
}
function set_union() {
    # calculate the union of two input sets
    # NOTE: the result will keep the order
    #
    # :param set_a:
    # :param set_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _i4cF_set_a=("${!1}")
    local -a _i4cF_set_b=("${!2}")

    # log for debug
    #declare -p _i4cF_set_a | sed -e 's/^/[set_union] >> /g' | log_lines debug
    #declare -p _i4cF_set_b | sed -e 's/^/[set_union] >> /g' | log_lines debug

    local -a _i4cF_set_d=`set_difference _i4cF_set_b[@] _i4cF_set_a[@]`

    # log for debug
    #declare -p _i4cF_set_d | sed -e 's/^/[set_union] >> /g' | log_lines debug

    local i e
    for i in ${!_i4cF_set_d[@]}
    do
        e="${_i4cF_set_d[$i]}"
        _i4cF_set_a+=("$e")
    done
    declare_p_val _i4cF_set_a
}
function __test_set_union() {
    local err_cnt=0
    local -a empty=()

    local -a a=(1 2 3 4)
    local -a b=(32 2)
    local -a r_t=(1 2 3 4 32)
    local -a r=`set_union a[@] b[@]`
    set_equal r[@] r_t[@] || { ((err_cnt+=1)); log_error "fail sub-test 1"; }

    local -a a=(1 2 3 4)
    local -a r=`set_union a[@] empty[@]`
    set_equal r[@] a[@] || { ((err_cnt+=1)); log_error "fail sub-test 2"; }

    test $err_cnt -eq 0
}
function setup_locale() {
    source /etc/profile

    ############################################################
    # Pick up a mostly valid locale, en_US.UTF-8, if current one is invalid.
    # Background:
    # - OSX default locale, UTF-8, is mostly invalid in Linux box,
    #   change it to en_US.UTF-8 if detected.
    local DEFAULT_locale=`locale -a | grep -Eix "en_US.UTF-8|en_US.utf8" | head -n1`
    if [ -z "$DEFAULT_locale" ]; then DEFAULT_locale=C; fi
    local item=""
    for item in LC_ALL LC_CTYPE LANG
    do
      local val=`locale 2>/dev/null | grep "^${item}=" | cut -d= -f2 | sed -e 's/\"//g'`
      if [ -z "$val" -o -z "$(locale -a 2>/dev/null | grep -Fx "$val")" ] && \
         [ "$val" != "$DEFAULT_locale" ]; then
        local cmd="$item=$DEFAULT_locale; export $item"
        #echo "$cmd" | $sudo tee -a /etc/profile
        eval "$cmd"

        log_info "Change $item from \"$val\" to \""`eval "echo \\\$$item"`"\""
      fi
    done
    # 确保LANG在LANGUAGE的第一个，保证显示的语言和设置的一致
    local _LANG=`echo "$LANG" | cut -d. -f1`
    if ! echo "$LANGUAGE" | grep -sq "^${_LANG}"; then
        export LANGUAGE=${_LANG}${LANGUAGE:+":"}${LANGUAGE}
    fi
}
function setup_os_flags() {
    function declare_g() { declare -g $1; }

    declare -a os_flags=(
      "is_osx"
      "is_linux"
      "is_rhel"
      "is_ubuntu"
      "ARCH"
      "OS_ID"
      "OS_VER"
      "OS_DISTRO"
      "G_expr_bin"
    ) && \

    for_each_op --silent declare_g ${os_flags[@]} && \

    if [ -f /etc/os-release ]; then
        setup_linux_os_flags
        is_osx=false

    elif command -v sw_vers >/dev/null; then
        setup_osx_os_flags
        is_linux=false
        is_rhel=false; is_ubuntu=false

    else
        log_error "Unsupported OS distribution. Abort!"
        exit 1
    fi && \

    if $is_osx; then
        if expr --version 2>&1 | grep -sq GNU; then
            G_expr_bin=expr
        elif gexpr --version 2>&1 | grep -sq GNU; then
            G_expr_bin=gexpr
        else
            log_error "utils.sh needs gnu expr program, use brew to install"
            false; return
        fi
    else
        G_expr_bin=expr
    fi && \

    for_each_op --silent declare_p ${os_flags[@]} | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
}
function setup_osx_os_flags() {
    # $ sw_vers
    # ProductName:        Mac OS X
    # ProductVersion:        10.13.5
    # BuildVersion:        17F77
    local sw_vers_lines=`sw_vers`
    eval "OS_ID=`echo "$sw_vers_lines" | grep "^ProductName:" | awk '{print $2}'`"
    eval "OS_VER=`echo "$sw_vers_lines" | grep "^ProductVersion:" | awk '{print $2}'`"
    ARCH=${ARCH:-`uname -m`}
    OS_DISTRO="${OS_ID}`echo "$OS_VER" | cut -d. -f-2 | sed -e 's/\.//g'`"

    is_osx=true
    is_rhel=false; is_ubuntu=false
}
function setup_linux_os_flags() {
    # rhel or ubuntu
    eval "OS_ID=`grep "^ID=" /etc/os-release | cut -d= -f2-`"
    # compatible with centos OS
    [ "$OS_ID" = "centos" ] && OS_ID="rhel"
    [ "$OS_ID" = "kylin" ] && OS_ID="rhel"
    # 7 for rhel, 16.04 for ubuntu
    eval "OS_VER=`grep "^VERSION_ID=" /etc/os-release | cut -d= -f2-`"
    ARCH=${ARCH:-`uname -m`}
    if [ $ARCH = "ppc64le" ]; then ARCH2=ppc64el; else ARCH2=$ARCH; fi
    if [ "$OS_ID" = "rhel" ]; then
        is_linux=true
        is_rhel=true; is_ubuntu=false;
        # rhel7
        OS_DISTRO="${OS_ID}`echo "$OS_VER" | cut -d. -f-1 | sed -e 's/\.//g'`"
    elif [ "$OS_ID" = "ubuntu" ]; then
        is_linux=true
        is_rhel=false; is_ubuntu=true;
        # ubuntu1604
        OS_DISTRO="${OS_ID}`echo "$OS_VER" | cut -d. -f-2 | sed -e 's/\.//g'`"
    else
        log_error "Unsupported OS distribution. Abort!"
        exit 1
    fi
}
function setup_gnu_utils() {
    declare -g G_expr_bin=expr
    if command -v gexpr >/dev/null; then
        G_expr_bin=gexpr
    fi
    declare -g tail=tail
    if command -v gtail >/dev/null; then
        tail=gtail
    fi
    declare -g date=date
    if command -v gdate >/dev/null; then
        date=gdate
    fi
    declare -g sed=sed
    if command -v gsed >/dev/null; then
        sed=gsed
    fi
    declare -g awk=awk
    if command -v gawk >/dev/null; then
        awk=gawk
    fi
    declare -g getopt=${getopt:-getopt}
    $getopt -T >/dev/null 2>&1
    if [ $? -ne 4 -a -x /usr/local/opt/gnu-getopt/bin/getopt ]; then
        getopt=/usr/local/opt/gnu-getopt/bin/getopt
    fi
}
function print_title() {
    echo -e "\n"
    echo "+-----------------------------------------------------------"
    echo "| $@"
    echo "+-----------------------------------------------------------"
    echo -e "\n"
}
function log_info_title() {
    true \
 && { cat <<EOF
#
# $@
#
EOF
} | sed -e 's/^/[I]: /g' >&2 \
 && true; \
}
function version_cmp() {
    local silent=false
    if [ "$1" = "--silent" ]; then silent=true; shift; fi
    # only for log message
    local pkg_name="$1"
    # compare operation
    local pkg_op="$2"
    # version real
    local pkg_verR="$3"
    # version expect
    local pkg_verE="$4"

    # "*" means matching any version which equals to no version expectation.
    if [ "$pkg_verE" = "*" ]; then
        pkg_verE=""
    fi

    local pkg_vmin=`echo -e "${pkg_verE}\n${pkg_verR}" | sort -V | grep -v "^$" | head -n1`
    local msg="name=\"$pkg_name\", verA=\"$pkg_verR\", op=\"$pkg_op\", verB=\"$pkg_verE\", vMin=\"$pkg_vmin\""

    # 比较成功的条件如下:
    # * 没有期望的版本，那么任何安装上的版本都算成功
    # * 完全一致，那么所有>=, <=, ==, =的op都算成功
    # * 非数字的前缀完全一致，那么所有>=, <=, ==, =的op都算成功
    #   NOTE: pip有xxxx+flag的格式语法，xxxx我称为非数字前缀
    # * sort -V的排序下，符合>=, >, <=, <的期望，就算成功
    if [ \( -z "$pkg_verE" -a -n "$pkg_verR" \) -o \
         \( -n "$pkg_verE" -a -n "$pkg_verR" -a \( \
             \( "${pkg_verE}"  = "${pkg_verR}" -a `$G_expr_bin "#$pkg_op" : "^#.*=$"` -gt 1 \) -o \
             \( "${pkg_verE}" != "${pkg_verR}" -a \( \
                 \( `$G_expr_bin "#$pkg_op" : "^#>.*$"` -gt 1 -a "${pkg_vmin}" = "${pkg_verE}" \) -o \
                 \( `$G_expr_bin "#$pkg_op" : "^#<.*$"` -gt 1 -a "${pkg_vmin}" = "${pkg_verR}" \) \
             \) \) \
         \) \) ]; then
        if ! $silent; then log_debug "${FUNCNAME[0]} succ: $msg"; fi
    else
        if ! $silent; then log_error "${FUNCNAME[0]} fail: $msg"; fi
        false
    fi
}
function __test_version_cmp() {
    local err_cnt=0
    log_warn "NotImplemented ${FUNCNAME[0]}"
    true || { ((err_cnt+=1)); log_error "fail sub-case 1"; }
    test $err_cnt -eq 0
}
function for_each_op() {
    local G_expr_bin=${G_expr_bin:-expr}
    local _ignore_error=false
    if [ "$1" = "--ignore_error" ]; then _ignore_error=true; shift; fi
    local _silent=false
    if [ "$1" = "--silent" ]; then _silent=true; shift; fi
    local _fs="$IFS"
    if [ "$1" = "--fs" ]; then
        _fs=$2; shift 2
    elif [ `$G_expr_bin "#$1" : "^#--fs="` -eq 6 ]; then
        _fs="${1/--fs=}"; shift
    fi

    # extract op
    local op=$1; shift

    # extract op partial args
    declare -a op_args=()
    while [ -n "$1" ];
    do
        if [ "$1" = "--" ]; then shift; break; fi
        op_args+=("$1")
        shift
    done

    # apply IFS
    local IFS_OLD="$IFS"
    IFS=$_fs

    # extract op input data
    declare -a op_data=($@)
    if [ ${#op_data[@]} -eq 0 ]; then
        op_data=(${op_args[@]})
        op_args=()
    fi

    # quick return if no input data
    local lcnt=${#op_data[@]}
    if [ $lcnt -eq 0 ]; then
        IFS="$IFS_OLD"
        return 0
    fi

    # loop run each input data
    local _i_5rYn=0
    local line=""
    for line in ${op_data[@]}
    do
        IFS="$IFS_OLD"
        [ -n "$line" ] || continue
        if ! $_silent; then
            print_title "Run \"$op\" at round $((_i_5rYn+1)) of $lcnt with parameter \"$line\""
        fi | log_lines debug
        $op ${op_args[@]} $line || $_ignore_error || break
        ((_i_5rYn+=1))
    done
    test $_i_5rYn -ge $lcnt
}
function __test_for_each_op() {
    local err_cnt=0

    local r truth
    r=`for_each_op --silent echo "a" "b" "c"`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail echo, rc"; }
    truth=`echo -e "a\nb\nc"`
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail echo"; }

    r=`for_each_op --silent echo -- "a" "b" "c"`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail echo with --, rc"; }
    truth=`echo -e "a\nb\nc"`
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail echo with --"; }

    r=`for_each_op --silent echo -n -- "a" "b" "c"`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail echo -n --, rc"; }
    truth="abc"
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail echo -n --"; }

    r=`for_each_op --silent --fs=: echo "a:b:c"`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail --fs=:, rc"; }
    truth=`echo -e "a\nb\nc"`
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail --fs=:"; }

    r=`for_each_op --silent --fs=: echo -n -- "a:b:c"`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail --fs=: echo -n --, rc"; }
    truth="abc"
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail --fs=: echo -n --"; }

    r=`for_each_op --silent --fs=$'\n' echo "a
b
c"`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail --fs=\\n, rc"; }
    truth=`echo -e "a\nb\nc"`
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail --fs=\\n"; }

    r=`for_each_op --silent ls -1d -- "/etc/hosts" "/tmp/$(uuidgen)" 2>/dev/null`
    [ $? -eq 0 ] && { ((err_cnt+=1)); log_error "fail last op error, rc"; }
    truth="/etc/hosts"
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail last op error"; }

    r=`for_each_op --ignore_error --silent ls -1d -- "/etc/hosts" "/tmp/$(uuidgen)" 2>/dev/null`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail last op error with ignore_error, rc"; }
    truth="/etc/hosts"
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail last op error with ignore_error"; }

    r=`for_each_op --silent ls -1d -- "/tmp/$(uuidgen)" "/etc/hosts" 2>/dev/null`
    [ $? -eq 0 ] && { ((err_cnt+=1)); log_error "fail middle op error, rc"; }
    [ -z "$r" ] || { ((err_cnt+=1)); log_error "Fail middle op error"; }

    r=`for_each_op --ignore_error --silent ls -1d -- "/tmp/$(uuidgen)" "/etc/hosts" 2>/dev/null`
    [ $? -eq 0 ] || { ((err_cnt+=1)); log_error "fail middle op error with ignore_error, rc"; }
    truth="/etc/hosts"
    [ "$r" == "$truth" ] || { ((err_cnt+=1)); log_error "Fail middle op error with ignore_error"; }

    test $err_cnt -eq 0
}
function for_each_line_op() {
    for_each_op --fs=$'\n' "$@"
}
# verify first, if failed, do op{eration} and verify again
# return verify result
function do_and_verify() {
    local verify_op="$1"
    local do_op="$2"
    local wait_op="$3"

    local _loop_cnt_3vJv=0
    while [ $_loop_cnt_3vJv -lt 2 ]; do
        # silent in first round
        if [ $_loop_cnt_3vJv -eq 0 ]; then
            $verify_op >/dev/null 2>&1;
        else
            $verify_op;
        fi && break;
        if [ $_loop_cnt_3vJv -eq 0 ]; then $do_op; fi
        $wait_op
        ((_loop_cnt_3vJv+=1))
    done
    test $_loop_cnt_3vJv -lt 2
}
function __test_do_and_verify() {
    local err_cnt=0
    # 测试_loop_cnt_3vJv的使用是可以的
    # 注意，要加eval到verify_op上，否则，不会执行${_loop_cnt_3vJv}的展开
    do_and_verify 'eval test ${_loop_cnt_3vJv} -gt 0' 'false' 'true' || {
        ((err_cnt+=1)); log_error "Fail sub-case 1"
    }
    test $err_cnt -eq 0
}
# download by checking cache first
function download_by_cache() {
    # pick up command line argument "cache_home", if there is
    local default_cache_home=~/.cache/download && \
    local cache_home=${cache_home:-${default_cache_home}} && \
    if [ "$1" = "--cache_home" ]; then
        cache_home=$2
        shift 2
    elif [ `$G_expr_bin "#$1" : "#--cache_home="` -eq 13 ]; then
        cache_home="`echo "$1" | cut -d= -f2-`"
        shift
    elif [ -z "$cache_home" ]; then
        log_error "Variable \"cache_home\" should not be empty for function \"${FUNCNAME[0]}\""
        false
    fi && \
    if [ ! -d $cache_home ]; then mkdir -p $cache_home >/dev/null; fi && \
    cache_home=`ls -d $cache_home 2>/dev/null` && \

    # dry-run to pick up hash location
    local dry_run=${dry_run:-false} && \
    if [ "$1" = "--dry-run" ]; then
        dry_run=true
        shift
    elif [ `$G_expr_bin "#$1" : "#--dry-run="` -eq 10 ]; then
        dry_run="`echo "$1" | cut -d= -f2-`"
        shift
    fi && \

    # calculate target hash location in the cache
    local url=$1 && \
    if [ "${url:0:1}" = "/" ]; then url="file://$url"; fi && \

    local f=`echo "$url" | awk -F/ '{print $NF}'` && \
    if [ -z "$f" ]; then true \
     && f=`echo "$url" | sha1sum | awk '{print $1}'` \
     && f=${f:0:8} \
     && log_warn "URL \"$url\" does not point to a file. Use hash(${f}) instead." \
     && true; \
    fi && \

    local d=${url%/${f}} && \
    local fsum=`echo "$f" | sum` && fsum=${fsum:0:2} && \
    local dsum=`echo "$d" | sum` && dsum=${dsum:0:2} && \
    local cache_dir=${cache_home}/$dsum/$fsum && \

    # it's dry-run's exit now
    if $dry_run; then echo "$cache_dir/$f"; return 0; fi && \

    if [ ! -d "$cache_dir" ]; then mkdir -p $cache_dir; fi && \

    # try downloading checksum first
    local url_sum=$2 && \
    local fcksum="" && \
    if [ -n "$url_sum" ]; then
        fcksum=`download_by_cache $url_sum`
        test -n "$fcksum"
    fi && \

    # try download target if not hit in cache
    local first_download=false && \
    if [ ! -f $cache_dir/$f ]; then
        log_info "Download and cache url \"$url\""
        local tmpn=`mktemp -u XXXX`
        first_download=true

        curl ${CURL_PROXY:+--proxy} ${CURL_PROXY} -SL $url -o $cache_dir/.$f.$tmpn
        local rc=$?

        if [ $rc -eq 0 ]; then
            mv $cache_dir/.$f.$tmpn $cache_dir/$f && \
            ls -ld $cache_dir/$f | sed -e 's/^/>> /g' | log_lines debug
        else
            log_error "Fail to download url \"$url\" with rc equals to $rc"
            rm -f $cache_dir/.$f.$tmpn
        fi && \

        (exit $rc)
    fi && \

    if [ -f $cache_dir/$f ]; then
        # verify checksum and clean cache if failed
        if [ -n "$fcksum" -a -f "$fcksum" ]; then
            if ! (cd $cache_dir && sha256sum -c $fcksum;); then
                log_error "Checksum mismatch for cached content of \"$cache_dir/$f\""
                if $first_download; then
                    log_info "Clean invalid cache content for \"$url\""
                    rm -f $cache_dir/$f
                    rmdir $cache_dir 2>/dev/null
                fi
                false
            fi
        # warn if purely cache hit w/o cksum verify
        elif ! $first_download; then
            log_warn "Cache hit w/o checksum verification for \"$cache_dir/$f\""
        fi && \
        echo "$cache_dir/$f"
    else
        false
    fi
}
function gen_lib_source_cmd() {
    local f_sh=$1
    local f_sh_url=$2
    local f_sh_sum=$3
    if ! command -v $f_sh >/dev/null; then
        if [ -f "$PROG_DIR/$f_sh" ]; then
            f_sh="$PROG_DIR/$f_sh"
        else
            f_sh=`download_by_cache $f_sh_url $f_sh_sum`
        fi
    fi >/dev/null
    if [ -n "$f_sh" ]; then
        echo "source $f_sh"
    else
        echo "false"
    fi
}
function filter_pkgs_groupby() {
    local default_grp=${1:-"10"}
    if awk --version 2>/dev/null | grep -sq "GNU Awk"; then
        true;
    else
        log_warn "AWK is not GNU version, filter_pkgs_groupby will not function correctly!"
    fi

    # put to default group, "10", if entry has no group specified
    awk -v default_grp=$default_grp '!/^[0-9]+:/ { print default_grp":"$0; next; } { print; }' | \
    # group by
    awk -F":" '
    {
      id=$1; sub(/^[^:]+:/, "");
      if (id in arr) { arr[id] = arr[id]" "$0; } else { arr[id] = $0; };
    }
    function cmp_num_idx(i1, v1, i2, v2) { return (i1 - i2); }
    END {
      PROCINFO["sorted_in"] = "cmp_num_idx"
      for (a in arr) print arr[a]
    }'
}
# detect if there is conda command available in current env
function has_conda() {
    command -v conda >/dev/null || declare -F conda >/dev/null
}
# shadow conda command
function _shadow_cmd_conda() {
    local _is_activate_related=false
    if [ "$1" = "activate" -o "$1" = "deactivate" ]; then
        _is_activate_related=true
    fi

    if ! do_and_verify \
        "declare -F conda" \
        'eval source $(dirname $(command -v conda)/)/../etc/profile.d/conda.sh' \
        'true' >/dev/null; then
        log_error "Conda(>4.6.14) environment was not properly configured in current shell"
        false
    fi && \
    if [ -z "${G_conda_c_info_s}" ]; then
        cache_conda_info_s
    fi && \
    # 再次source这个文件，确保是符合conda调用规范的。因为发现在shell里面调用conda的时候，有时候
    # 之前source这个文件的效果，不能被shell里面的conda所识别。
    source `echo "${G_conda_c_info_s}" | grep ^sys.prefix: | awk '{print $2}'`/etc/profile.d/conda.sh && \
    conda $@

    local _rc=$? && \
    if [ "$_is_activate_related" = "true" ]; then
        #
        # be careful to endless recursive call
        #
        # NOTE:
        # * if you update post-process of activate/deactivate, remember
        #   to update your calling side in case these flags needs to be udpated
        #
        setup_conda_flags && \
        setup_pip_flags && \
        true
    fi
    (exit $_rc)
}
function __test__shadow_cmd_conda() {
    local err_cnt=0
    #
    # 这个怎么测呢，要覆盖conda的不同版本，例如:
    # 1) conda<4.6, pre
    # 2) conda==4.6, stable
    # 3) conda>4.6, dev, such as 4.7
    #
    # 要覆盖用户不同的shell rc/profile环境，例如：
    # 1) 有无conda init <SHELL>的前置导入
    # 2) 有无conda.sh的前置导入
    # 3) 有无conda/bin在PATH里面的设定
    # 4) 有无conda/condabin在PATH里面的设定，conda>=4.6
    # 5) 有无active的conda env
    #
    log_warn "fake test, 我想桃桃了。"
    test $err_cnt -eq 0
}
function __test__shadow_cmd_conda_info_s() {
    local err_cnt=0

    local conda=_shadow_cmd_conda

    # 撤掉测试前已有的ve，以防干扰
    $conda deactivate

    # 先清掉cache
    G_conda_c_info_s=""
    # 确保清掉了
    test -z "$G_conda_c_info_s" || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 1, \"`declare -p G_conda_c_info_s`\"";
    }

    # 激活一个ve，看info_s被cache住没
    $conda activate base
    echo "$G_conda_c_info_s" | grep -sq "CONDA_DEFAULT_ENV: base" || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 2, \"`declare -p G_conda_c_info_s`\"";
    }

    # 解激活后，info_s的缓冲应该还在
    $conda deactivate
    [ -z "`echo \"$G_conda_c_info_s\" | grep \"CONDA_DEFAULT_ENV:\"`" -a -n "$G_conda_c_info_s" ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 3, \"`declare -p G_conda_c_info_s`\"";
    }
    test $err_cnt -eq 0
}
function cache_conda_info_s() {
    if has_conda; then
        export G_conda_c_info_s="`conda info -s`"
    else
        # TODO: 是不是激活一下conda profile，然后再试
        false
    fi
}
function cache_conda_info_json() {
    if has_conda; then
        export G_conda_c_info_json="`conda info --json`"
    else
        # TODO: 是不是激活一下conda profile，然后再试
        false
    fi
}
# different pip version has different command line options
function setup_conda_flags() {
    function get_conda_prefix_from_info_s() {
        echo "${G_conda_c_info_s}" | grep "^CONDA_PREFIX:" | awk '{print $2}'
    }
    function get_conda_sys_prefix_from_info_s() {
        echo "${G_conda_c_info_s}" | grep "^sys\.prefix:" | awk '{print $2}'
    }
    if has_conda; then
        if [ -z "$G_conda_c_info_s" ]; then cache_conda_info_s; fi && \
        conda_install_home=`echo "$G_conda_c_info_s" | grep ^sys.prefix: | awk '{print $2}'`
    fi
    local conda_profile=$conda_install_home/etc/profile.d/conda.sh
    if do_and_verify "has_conda" "source $conda_profile" 'true' 2>/dev/null; then
        # 准备cache info_s信息，如果：
        # 1) 没有cache信息
        # 2) 好像不一致了
        local _conda_prefix="`get_conda_prefix_from_info_s`"
        if [ -z "$G_conda_c_info_s" -o "$_conda_prefix" != "$CONDA_PREFIX" ]; then
            cache_conda_info_s
        fi
        G_conda_bin="`get_conda_sys_prefix_from_info_s`/bin/conda"
        G_conda_install_flags=("--yes" ${conda_install_flags_extra[@]})
        if true || [ "`get_conda_active_prefix`" != "$_conda_prefix" ]; then
            cache_conda_info_json
        fi
    fi
    # Remove $CONDA_PREFIX/bin from PATH only if conda function was not the first priority.
    if [ "`command -v conda`" != "conda" -a -n "${G_conda_bin}" ]; then
        export PATH=`echo "$PATH" | tr ':' '\n' | grep -vF "${G_conda_bin%/*}" | xargs | tr ' ' ':'`
        log_info "Remove ${G_conda_bin%/*} from PATH"
    fi
    declare -a conda_flags=(`set | grep "^G_conda" | cut -d= -f1 | sort -u`)
    for_each_op --silent declare_p ${conda_flags[@]} | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
}
# different pip version has different command line options
function setup_pip_flags() {
    #
    # NOTE: activate conda env before calling this setup, if you are actually means the pip in conda env
    #
    #if $use_conda && has_conda; then
    #    local env_activated=false
    #    local _active_prefix="`get_conda_active_prefix`"
    #    if [ -n "$_active_prefix" ]; then
    #        env_activated=true
    #    fi
    #
    #    if $env_activated || conda_activate_env $conda_env_name; then
    #        G_pip_bin=`for_each_op --ignore_error --silent ls -1d -- ${CONDA_PREFIX:+${CONDA_PREFIX}/bin/pip} $(command -v pip) | head -n1`
    #        G_python_ver=`python --version 2>&1 | grep ^Python | awk '{print $2}'`
    #        $env_activated || _shadow_cmd_conda deactivate
    #    fi
    #else
        G_python_bin=`command -v ${1:-${G_python_bin:-python3}}`
        G_python_ver=`${G_python_bin} --version 2>&1 | grep ^Python | awk '{print $2}'`
        G_pip_bin="${G_python_bin} -m pip"
    #fi
    G_python_ver_major=`echo "$G_python_ver" | cut -d. -f1`
    G_python_ver_minor=`echo "$G_python_ver" | cut -d. -f2`

    local pip=$G_pip_bin
    local pip_version=`$pip --version 2>/dev/null | awk '{print $2}' | head -n1`
    if [ -n "$pip_version" ] && version_cmp pip ">=" "$pip_version" "9.0.1"; then
        G_pip_install_flags=("--upgrade" "--upgrade-strategy" "only-if-needed")
        G_pip_list_flags=("--format freeze")
    else
        G_pip_install_flags=("--upgrade")
        G_pip_list_flags=()
    fi
    G_pip_install_flags+=(${pip_install_flags_extra[@]})
    declare -a pip_flags=(`set | grep -E "^G_pip|^G_python" | cut -d= -f1 | sort -u`)
    for_each_op --silent declare_p ${pip_flags[@]} | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
}
function setup_apt_flags() {
    if $notty; then
        G_apt_bin="env DEBIAN_FRONTEND=noninteractive apt-get"
    else
        G_apt_bin="apt-get"
    fi
    G_apt_install_flags=(
    "-y"
    "--allow-unauthenticated"
    "--no-install-recommends"
    )
    declare -a apt_flags=(`set | grep "^G_apt" | cut -d= -f1 | sort -u`)
    for_each_op --silent declare_p ${apt_flags[@]} | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
}
# clean cache directory to make docker image efficient
function clean_pip_cache() {
    if [ "$as_root" = "true" ]; then
        $sudo ${sudo:+"-i"} bash -c 'rm -rf $HOME/.cache/pip'
    else
        rm -rf $HOME/.cache/pip
    fi
}
function filter_pkgs_yum() {
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "rpm:" and non prefix pkgs
    grep -Ev "^deb:|^pip:|^conda:" | sed -e 's/^rpm://g' | \
    filter_pkgs_groupby 10
}
function filter_pkgs_deb() {
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "deb:" and non prefix pkgs
    grep -Ev "^rpm:|^pip:|^conda:" | sed -e 's/^deb://g' | \
    filter_pkgs_groupby 10
}
function filter_pkgs_pip() {
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "pip:" prefix only pkgs
    awk '/^pip:/ { sub(/^pip:/,""); print; }' | \
    filter_pkgs_groupby 10
}
function filter_pkgs_conda() {
    if ! $use_conda; then return; fi
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "conda:" prefix only pkgs
    awk '/^conda:/ { sub(/^conda:/,""); print; }' | \
    filter_pkgs_groupby 10
}
function pkg_install_yum() {
    local pkgs="$@"
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    $_sudo yum ${G_yum_flags[@]} install -y $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "python2-pip|python3-pip|python34-pip|rh-python38-python-pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_deb() {
    local pkgs="$@"
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    local _apt_install_flags=${apt_install_flags:-${G_apt_install_flags[@]}}
    $_sudo ${G_apt_bin} install ${_apt_install_flags} $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "python-pip|python3-pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_pip() {
    local pip=$G_pip_bin
    local pkgs="$@"
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    if ! $_sudo test -z "$PYTHONUSERBASE" -o -d "$PYTHONUSERBASE"; then
        $_sudo mkdir -p $PYTHONUSERBASE
    fi && \
    $_sudo ${_sudo:+"-i"} env ${PYTHONUSERBASE:+"PYTHONUSERBASE=$PYTHONUSERBASE"} \
        $pip install ${PYTHONUSERBASE:+"--user"} ${G_pip_install_flags[@]} $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_conda() {
    if ! $use_conda; then return; fi
    local pkgs="$@"
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    if [ -n "$conda_envs_dir" ]; then
        $_sudo $G_conda_bin install \
            ${conda_env_name:+"--prefix=${conda_envs_dir}/${conda_env_name}"} \
            ${G_conda_install_flags[@]} $pkgs
    else
        $_sudo $G_conda_bin install \
            ${conda_env_name:+"--name=${conda_env_name}"} \
            ${G_conda_install_flags[@]} $pkgs
    fi
}
function pkg_list_installed_yum() {
    local pkgs=($@)
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    # yum list installed对于存在部分没有安装的包，他也会返回成功，这不是我们期望的
    local _lines=`$_sudo yum ${G_yum_flags[@]} list installed ${pkgs[@]} | grep -A9999 "Installed Packages" | tail -n+2`
    # 有时候yum会把一条记录显示为多行，后续行有缩进，我们滤掉那些缩进行
    local _cnt=`echo "$_lines" </dev/null | grep '^[a-zA-Z0-9_.-]' | awk 'END {print NR}'`
    echo "$_lines"
    test $_cnt -eq ${#pkgs[@]}
}
function pkg_list_installed_deb() {
    local pkgs="$@"
    local pkgs_m=`echo "$pkgs" | tr ' ' '\n' | sed -e 's/=.*$//g' | xargs`
    env DPKG_PAGER="cat" dpkg -l $pkgs_m && \
    env DPKG_PAGER="cat" dpkg -s $pkgs_m >/dev/null
}
function pkg_list_installed_pip() {
    local pip=$G_pip_bin
    local pkgs="$@"
    # remove: pkg bundles("xxx[bundle1,bundle2]"), version pairs(xxx>=1.1.0,<=2.0.0)
    local regex=`echo "$pkgs" | tr ' ' '\n' | \
                 sed \
                     -e 's/\[.*\]//g' \
                     -e 's/[<=>]=.*$//g' \
                     -e 's/[<>].*$//g' \
                     -e 's/^\(.*\)$/^\1==/g' | \
                 xargs | tr ' ' '|'`
    local cnt=`echo "$pkgs" | wc -w`
    # we'd better to compare package name case insensitive.
    local lines=`{ if [ -n "$PYTHONUSERBASE" ]; then
                       env PYTHONUSERBASE=$PYTHONUSERBASE \
                         $pip list --user ${G_pip_list_flags[@]};
                   fi; \
                   $pip list ${G_pip_list_flags[@]}; \
                 } | \
                 sed -e 's/ *(\(.*\))$/==\1/g' | \
                 grep -Ei "$regex" | \
                 sort -u`
    local lcnt=`echo "$lines" | grep -v "^$" | wc -l`
    echo "$lines"
    if [ $lcnt -ne $cnt ]; then log_error "lcnt=$lcnt, cnt=$cnt"; fi
    test $lcnt -eq $cnt
}
function pkg_list_installed_conda() {
    if ! $use_conda; then return; fi
    local pkgs="$@"
    local regex=`echo "$pkgs" | tr ' ' '\n' | \
                 sed -e 's/[<=>]=.*$//g' -e 's/[<=>].*$//g' -e 's/^\(.*\)$/^\1==/g' | \
                 xargs | tr ' ' '|'`
    local cnt=`echo "$pkgs" | wc -w`
    # we'd better to compare package name case insensitive.
    local _alias=""
    if [ -n "$conda_env_prefix" ]; then
        _alias="--prefix $conda_env_prefix"
    else
        _alias="--name $conda_env_name"
    fi
    # for conda>=4.5,<4.6 pip pkg in conda shows as "<pip>"
    # for conda>=4.6, pip pkg shows as pypi channel.
    local lines=`${G_conda_bin} list $_alias | \
                   awk '($3 != "<pip>") && ($4 != "pypi") {print $1"=="$2}' | \
                   sed -e 's/ *(\(.*\))$/==\1/g' | \
                   grep -Ei "$regex" | \
                   sort -u`
    local lcnt=`echo "$lines" | grep -v "^$" | wc -l`
    echo "$lines"
    if [ $lcnt -ne $cnt ]; then log_error "lcnt=$lcnt, cnt=$cnt"; fi
    test $lcnt -eq $cnt
}
function pkg_verify_yum() {
    declare -a pkgs=($@)
    if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    declare -a pkgs_m=(`echo "${pkgs[@]}" | tr ' ' '\n' | sed -e 's/=.*$//g'`)
    # local var=`cmd <arg>`; rc=$?  这样的形式，会导致后一条rc总是取到0，所以换成2条语句
    local out_lines=""
    out_lines=`$_sudo rpm -V ${pkgs_m[@]} 2>&1`
    local rc=$?
    if [ $rc -ne 0 -a -n "$out_lines" ]; then
        if ! is_running_in_docker; then
            log_error "Fail to verify yum packages \"${pkgs[@]}\""
            echo "$out_lines" | sed -e 's/^/>> /g' | log_lines error
        fi
        false
    fi

    # 在docker容器里面验证包的时候，有时候会因为容器的aufs等文件系统扥原因，
    # 导致验证错误，实际是没问题的，这里旁路一下，避免这样无效的失败
    local rc=$?
    if [ $rc -ne 0 ] && is_running_in_docker; then
        log_info "Fall back to yum pkg list from real verification in docker container due to known problem."
        if ! pkg_list_installed_yum ${pkgs[@]}; then
            log_error "Fail to verify yum packages \"${pkgs[@]}\""
            echo "$out_lines" | sed -e 's/^/>> /g' | log_lines error
            false
        else
            # reset rc as if it was succ
            rc=0
        fi
    fi
    (exit $rc)
}
function pkg_verify_deb() {
    local -a pkgs=($@)
    if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    declare -a pkgs_m=(`echo "${pkgs[@]}" | tr ' ' '\n' | sed -e 's/=.*$//g'`)
    local out_lines=`$_sudo dpkg -V ${pkgs_m[@]} 2>&1`
    if [ -n "$out_lines" ]; then
        if ! is_running_in_docker; then
            log_error "Fail to verify deb packages \"${pkgs[@]}\""
            echo "$out_lines" | sed -e 's/^/>> /g' | log_lines error
        fi
        false
    fi

    # 在docker容器里面验证包的时候，有时候会因为容器的aufs等文件系统扥原因，
    # 导致验证错误，实际是没问题的，这里旁路一下，避免这样无效的失败
    local rc=$?
    if [ $rc -ne 0 ] && is_running_in_docker; then
        log_info "Fall back to deb pkg list from real verification in docker container due to known problem."
        pkg_list_installed_deb ${pkgs[@]}
        rc=$?
    fi
    (exit $rc)
}
function _cmp_op_pair() {
    local pkg_op_pair="$1"
    local pkg_op=(  `echo "$pkg_op_pair" | cut -d'|' -f1  -s`)
    local pkg_verE=(`echo "$pkg_op_pair" | cut -d'|' -f2- -s`)

    if [ -n "$pkg_verE" ]; then
        version_cmp "$pkg_name" "$pkg_op" "$pkg_verR" "$pkg_verE"
    elif [ ! -n "$pkg_verR" ]; then
        log_error "Missing pkg \"$pkg_op_pair\""
        false
    fi
}
function pkg_verify_pip() {
    declare -a pkgs=($@)
    if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi

    # pkg_verify_conda will reuse most of logic of this function
    # so, we pick the fake conda pkg list output as faked pip output
    local out_lines=${conda_out_lines:-"`pkg_list_installed_pip ${pkgs[@]}`"}
    if [ -z "$out_lines" ]; then return 1; fi
    #echo "$out_lines" | sed -e 's/^/>> [pip]: /g' | log_lines debug

    local cnt=${#pkgs[@]}
    local i=0
    local pkg=""
    for pkg in ${pkgs[@]}
    do
        # separate the pkg_name, operator and target version
        # for pkg_name, remove pip pkg's bundle xxx[bundle1,bundle2], such as celery[redis]<5.0
        # for pkg_version, remove pip pkg's +xxx version suffix, such as torch==1.7.1+cu101
        local pkg_line=`echo "$pkg" | sed -e 's/\([<=>!]\)/|\1/'`
        local pkg_name=`echo "$pkg_line" | cut -d'|' -f1 | sed -e 's/\[.*\]//g'`
        declare -p pkg_line | sed -e 's/^/>> [fzw]: /g' | log_lines debug
        declare -a pkg_op_pairs=(`echo "$pkg_line" | cut -d'|' -f2- | tr ',' '\n' | sed \
            -e 's/^\([<=>!]=\)\([^<=>].*\)$/\1|\2/g' \
            -e 's/^\([<>]\)\([^<=>].*\)$/\1|\2/g' \
            -e 's/\+.*$//g' \
        `)
        declare -p pkg_op_pairs | sed -e 's/^/>> [fzw]: /g' | log_lines debug

        # we'd better to compare pip package name case insensitive.
        # for pkg_version, remove pip pkg's +xxx version suffix, such as torch==1.7.1+cu101
        local pkg_verR=`echo "$out_lines" | grep -i "^$pkg_name==" | sed \
            -e 's/^.*==//g' \
            -e 's/\+.*$//g' \
        `

        for_each_op --silent _cmp_op_pair ${pkg_op_pairs[@]} || break
        ((i+=1))
    done
    if [ $i -ne $cnt ]; then log_error "i=$i, cnt=$cnt"; fi
    test $i -eq $cnt
}
function pkg_verify_conda() {
    if ! $use_conda; then return; fi

    declare -a pkgs=($@)
    if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi

    local conda_out_lines="`pkg_list_installed_conda ${pkgs[@]}`"
    if [ -n "$conda_out_lines" ]; then
        pkg_verify_pip ${pkgs[@]}
    else
        log_error "Fail to verify any of package in \"${pkgs[@]}\""
        false
    fi
}
function filter_pkgs() {
    if $is_rhel; then
        filter_pkgs_yum $@
    elif $is_ubuntu; then
        filter_pkgs_deb $@
    fi
    filter_pkgs_pip $@
    if $use_conda; then
        filter_pkgs_conda $@
    fi
}
function pkg_meta_clean_yum() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && $_sudo yum clean all \
 && true;
}
function pkg_meta_clean_deb() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && $_sudo apt-get clean \
 && true;
}
function pkg_meta_clean_conda() {
    if command -v conda >/dev/null 2>&1 || declare -F conda >/dev/null 2>&1; then
        conda clean --all -y
    fi
}
function pkg_meta_clean_download_cache() {
    local tmpd=`mktemp -d /tmp/XXXXXXXX`
    rsync -rv --delete $tmpd/ ~/.cache/download/ || true
    rmdir $tmpd
}
function pkg_meta_clean() {
    if $is_rhel; then
        pkg_meta_clean_yum $@
    elif $is_ubuntu; then
        pkg_meta_clean_deb $@
    fi
    if $use_conda; then
        pkg_meta_clean_conda $@
    fi
    pkg_meta_clean_download_cache $@
}
# meta functions
for item in pkg_install pkg_list_installed pkg_verify
do
    eval 'function '$item'() {
        if $is_rhel; then
            for_each_line_op '$item'_yum "`filter_pkgs_yum $@`"
        elif $is_ubuntu; then
            for_each_line_op '$item'_deb "`filter_pkgs_deb $@`"
        fi && \
        if $use_conda; then
            for_each_line_op '$item'_conda "`filter_pkgs_conda $@`" && \
            if [ "'$item'" = "pkg_install" ]; then
                pkg_list_installed $@ | sed -e "s/^/[middle]>> /g" | log_lines debug
            fi
        fi && \
        for_each_line_op '$item'_pip "`filter_pkgs_pip $@`"
    }'
done
# anchor code for usage() helper
echo '
function pkg_install() { true; }
function pkg_list_installed() { true; }
function pkg_verify() { true; }
' >/dev/null
function urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
       c=${string:$pos:1}
       case "$c" in
          [-_.~a-zA-Z0-9] ) o="${c}" ;;
          * )               printf -v o '%%%02x' "'$c"
       esac
       encoded+="${o}"
    done
    echo "${encoded}"    # You can either set a return variable (FASTER)
    REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}
function urlencode2() {
    echo -ne $1 | hexdump -v -e '/1 "%02x"' | sed 's/\(..\)/%\1/g'
}
# Returns a string in which the sequences with percent (%) signs followed by
# two hex digits have been replaced with literal characters.
function urldecode() {
  # This is perhaps a risky gambit, but since all escape characters must be
  # encoded, we can replace %NN with \xNN and pass the lot to printf -b, which
  # will decode hex for us

  printf -v REPLY '%b' "${1//%/\\x}" # You can either set a return variable (FASTER)

  echo "${REPLY}"  #+or echo the result (EASIER)... or both... :p
}
function urldecode2() {
    printf '%b' "${1//%/\\x}"
}
function get_realpath() {
    # --------------------------
    # Copied from stackoverflow
    # https://stackoverflow.com/a/19250873 from @AsymLabs
    [ -f "$1" -o -d "$1" ] || return 1 # failure : file does not exist.
    [ -n "$no_symlinks" ] && local pwdp='pwd -P' || local pwdp='pwd' # do symlinks.
    echo "$( cd "$( echo "${1%/*}" )" 2>/dev/null; $pwdp )"/"${1##*/}" # echo result.
    return 0 # success
}
function listFunctions() {
    declare -F | awk '{print $3}'
}
function __test_listFunctions() {
    local err_cnt=0

    local lines=`listFunctions`
    [ `declare -F | awk 'END{print NR}'` -eq `echo "$lines" | awk 'END{print NR}'` ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 1";
    }
    echo "$lines" | grep -sqx "${FUNCNAME[0]}" || {
        ((err_cnt+=1)); _fail_unit_test "sub-case 2";
    }
    test $err_cnt -eq 0
}
#
# bsd and sys-v compatible pstree
#
function pstree() {
    local psinfo=`ps -o pid=,ppid= -ax | awk '{print $1,$2}' | sort -t' ' -k2 -n`
    local pids="$@"
    local pids_old=""
    while [ "$pids" != "$pids_old" ];
    do
        [ -n "$pids" ] || break
        pids_old="$pids"
        local regex=`echo "$pids" | sed -e 's/ /$| /g' -e 's/^/ /' -e 's/$/\$/'`
        pids=`{
            echo "$pids" | tr ' ' '\n';
            echo "$psinfo" | grep -E "$regex" | cut -d' ' -f1;
        } | sort -u | xargs`
    done
    [ -n "$pids" ] && echo "$pids"
}
command -v usleep >/dev/null || \
function usleep() {
    local num=$1
    sleep `awk -vnum=$num 'END{print num / 1000000}' </dev/null`
}
function get_relative_path() {
    local no_symlinks=true

    local ref_path=$1
    if [ -d "$ref_path" ]; then ref_path+="/"; fi
    ref_path=`get_realpath $ref_path`
    if [ -z "$ref_path" ]; then return 1; fi
    if [ ! -d "$ref_path" ]; then ref_path=`dirname $ref_path`; fi

    local rel_path=`get_realpath $2` || return 1
    if [ -z "$rel_path" ]; then return 1; fi

    local IFS_OLD=$IFS
    IFS=$'\/'
    local -a ref_path_a=($ref_path)
    local -a rel_path_a=($rel_path)
    IFS=$IFS_OLD

    local ref_len=${#ref_path_a[@]}
    local rel_len=${#rel_path_a[@]}
    local min_len=$ref_len
    if [ $ref_len -gt $rel_len ]; then
        min_len=$rel_len
    fi

    local pos=0
    #declare -p ref_path_a >&2
    #declare -p rel_path_a >&2
    for pos in `seq 0 $((min_len-1))`
    do
        [ "${ref_path_a[$pos]}" == "${rel_path_a[$pos]}" ] || break
    done
    ((ref_len-=pos+1))
    ((rel_len-=pos+1))
    local rst=""
    local idx=0
    for idx in `seq 0 $((ref_len))`
    do
        rst+=${rst:+"/"}..
    done
    for idx in `seq 0 $((rel_len))`
    do
        rst+=${rst:+"/"}${rel_path_a[$((idx+pos))]}
    done
    (cd $ref_path; ls -d $rst)
}
function __test_get_relative_path() {
    local err_cnt=0

    local tmp_dir=`mktemp -d /tmp/XXXXXX`
    mkdir -p $tmp_dir/a/b/c
    mkdir -p $tmp_dir/1/2/3
    touch $tmp_dir/a/b/b_1.txt
    touch $tmp_dir/a/b/c/c_1.txt
    touch $tmp_dir/a/a_1.txt
    touch $tmp_dir/1/2/3/3_1.txt
    touch $tmp_dir/1/2/2_1.txt
    touch $tmp_dir/1/1_1.txt
    ln -s a/b $tmp_dir/B

    r=`get_relative_path $tmp_dir/a/b $tmp_dir/a/a_1.txt`
    [ "../a_1.txt" == "$r" ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 1, \"$r\"";
    }

    r=`get_relative_path $tmp_dir/a/b/ $tmp_dir/a/a_1.txt`
    [ "../a_1.txt" == "$r" ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 2, \"$r\"";
    }

    r=`get_relative_path $tmp_dir/a/b/b_1.txt $tmp_dir/a/a_1.txt`
    [ "../a_1.txt" == "$r" ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 3, \"$r\"";
    }

    r=`get_relative_path $tmp_dir/B $tmp_dir/a/a_1.txt`
    [ "../a_1.txt" == "$r" ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 4, \"$r\"";
    }

    r=`get_relative_path $tmp_dir/B/ $tmp_dir/a/a_1.txt`
    [ "../a_1.txt" == "$r" ] || {
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 5, \"$r\"";
    }

    #find $tmp_dir -exec ls -ld {} \;
    [ -d "$tmp_dir" ]; rm -rf $tmp_dir
    test $err_cnt -eq 0
}
function monitor_and_terminate_timeout_process() {
    local pattern=$1
    local timeout=$2
    local sleep_interval=$3
    local shell_pid=$4
    local -a exclude_pids=()

    if [ -z "$pattern" ]; then
        pattern="[a-zA-Z0-9]"
    else
        shift
    fi
    if [ -z "$timeout" ]; then
        timeout=-1
    else
        shift
    fi
    if [ -z "$sleep_interval" ]; then
        sleep_interval=10
    else
        shift
    fi
    if [ -z "$shell_pid" -o "$shell_pid" = "-" ]; then
        shell_pid=$$
    elif [ -n "$shell_pid" ]; then
        shift
    fi
    exclude_pids=($@)

    local t_beg=`date "+%s"`
    local killing_iter=0
    while true;
    do
        local -a _pids_tree=(`pstree $shell_pid`)
        local -a _pids=`set_difference _pids_tree[@] exclude_pids[@]`
        if [ "${#_pids[@]}" -eq 0 ]; then
            killing_iter=0
            break
        fi

        local _lines=`ps -opid=,command= -p ${_pids[@]}`
        local -a _pids_pattern=(`echo "$_lines" | grep -E "$pattern" | awk '{print $1}'`)
        if [ "${#_pids_pattern[@]}" -eq 0 ]; then
            killing_iter=0
            break
        fi

        local t_remains=`$G_expr_bin ${timeout} - $(date "+%s") + ${t_beg}`
        if [ "$t_remains" -le 0 -a "$timeout" -gt 0 ]; then
            if [ "$killing_iter" -eq 0 ]; then
                log_warn "Terminate following timeout process..."
                ps -o pid,ppid,command -p ${_pids_pattern[@]} | sed -e 's/^/>> /g' | log_lines warn

                kill -TERM ${_pids_pattern[@]}
                ((killing_iter+=1))

            elif [ "$killing_iter" -eq 1 ]; then
                log_warn "Kill following timeout process..."
                ps -o pid,ppid,command -p ${_pids_pattern[@]} | sed -e 's/^/>> /g' | log_lines warn

                kill -KILL ${_pids_pattern[@]}
                ((killint_iter+=1))

            else
                log_error "Fail to terminate timeout process"
                ps -o pid,ppid,command -p ${_pids_pattern[@]} | sed -e 's/^/>> /g' | log_lines error
            fi
        fi
        sleep $sleep_interval
    done
    test $killing_iter -gt 0
}
function __test_monitor_and_terminate_timeout_process() {
    local err_cnt=0

    local -a pids=(`pstree $$`)
    monitor_and_terminate_timeout_process "sleep" 5 1 - ${pids[@]} &
    local t_beg=`date "+%s"`
    /bin/sleep 120
    local rc=$?
    local dur=`date "+%s"`
    ((dur-=t_beg))
    if [ $rc -eq 0 -o $dur -gt 6 ]; then
        ((err_cnt+=1)); log_error "Fail ${FUNCNAME[0]} sub-case 1, \"dur=$dur, rc=$rc\"";
    else
        log_debug "succ: sub-case 1, dur=$dur, rc=$rc"
    fi
    test $err_cnt -eq 0
}
declare -F usage >/dev/null || \
function usage() {
    echo "Usage $PROG_NAME"
    listFunctions | grep -v "^_" | sed -e 's/^/[cmd] >> /g' | log_lines info
    log_info "cmd=run_unit_test -- test_<function_name> | @all"
    exit 0
}
function get_cpu_quota_from_cg_cpu_cfs_quota_us() {
    local G_expr_bin=${G_expr_bin:-expr}
    local ref_pid=$1
    if [ -z "$ref_pid" ]; then ref_pid=$$; fi

    local cpu_subsys_hierarchy=`awk '$1 == "cpu" { print $2; }' /proc/cgroups`
    if [ -z "$cpu_subsys_hierarchy" ]; then return 1; fi

    local cpu_subsys_hierarchy_mnt=`mount -v -t cgroup | grep -w cpu | cut -d' ' -f3 | head -n1`
    if [ -z "$cpu_subsys_hierarchy_mnt" ]; then return 1; fi

    local cpu_cg=`grep "^${cpu_subsys_hierarchy}:" /proc/${ref_pid}/cgroup | cut -d: -f3 | head -n1`
    if [ -z "$cpu_cg" ]; then return 1; fi

    # 在docker内，有时候看到的cg_cpu实际上不存在(?为啥)，这时候，转而用cg顶层的quota
    if [ ! -e "${cpu_subsys_hierarchy_mnt}${cpu_cg}" ]; then true \
     && echo "[W]: cpu cg \"${cpu_cg}\" does not exist. Use root cg in the hierarchy instead for quota!" >&2 \
     && cpu_cg="" \
     && true; \
    fi
    if [ ! -e "$cpu_subsys_hierarchy_mnt${cpu_cg}/cpu.cfs_quota_us" ]; then return 1; fi
    local cpu_cfs_quota_us=$(<$cpu_subsys_hierarchy_mnt${cpu_cg}/cpu.cfs_quota_us)
    if [ "$cpu_cfs_quota_us" == "-1" ]; then return 2; fi

    if [ ! -e "$cpu_subsys_hierarchy_mnt${cpu_cg}/cpu.cfs_period_us" ]; then return 1; fi
    local cpu_cfs_period_us=$(<$cpu_subsys_hierarchy_mnt${cpu_cg}/cpu.cfs_period_us)
    #echo "scale=0; ${cpu_cfs_quota_us} / ${cpu_cfs_period_us}" | bc -l
    $G_expr_bin ${cpu_cfs_quota_us} \/ ${cpu_cfs_period_us}
}
function get_cpu_quota_from_lscpu() {
    ls -1d /sys/devices/system/cpu/cpu[0-9]* | wc -l
}
function get_cpu_quota() {
    local cpu_quota=`get_cpu_quota_from_cg_cpu_cfs_quota_us $@ </dev/null 2>/dev/null`
    if [ -n "$cpu_quota" ]; then echo "$cpu_quota"; return 0; fi

    cpu_quota=`get_cpu_quota_from_lscpu`
    if [ -n "$cpu_quota" ]; then echo "$cpu_quota"; return 0; fi

    # default to 1 if cannot get from env
    echo 1
}
function envsubst_enh() {
    local IN_FILE=$1
    local OUT_FILE=$2
    local TMP_DIR=${TMP_DIR:-/tmp}
    set -x
    local TMP_FILE=`mktemp ${TMP_DIR}/XXXXXXXX` && \
    if [ -z "$IN_FILE" -o "${IN_FILE}" = "-" ]; then
        IN_FILE=$TMP_FILE.stdin
        cat - >$IN_FILE
    fi && \
    if [ -z "$OUT_FILE" ]; then
        OUT_FILE=.stdout
    fi && \
    # generate updated file
    eval "echo \"$(<${IN_FILE})\"" >$TMP_FILE && \
    # replace IN_FILE with the updated one, if any diff
    if ! cmp -s $IN_FILE $TMP_FILE; then
        # log for debug
        {
            grep -v "^ *#" $IN_FILE  > $TMP_FILE.s.orig
            grep -v "^ *#" $TMP_FILE > $TMP_FILE.s
            cat $TMP_FILE.s | sed -e 's/^/[envsubst updated '"$(basename $OUT_FILE)"'] >> /g' | log_lines debug
            diff -u $TMP_FILE.s.orig $TMP_FILE.s | sed -e 's/^/[envsubst diff '"$(basename $OUT_FILE)"'] >> /g' | log_lines debug
            rm -f $TMP_FILE.s{,.orig} 2>/dev/null
        }
        if [ "$OUT_FILE" = ".stdout" ]; then
            cat $TMP_FILE \
         && rm $TMP_FILE \
         && true; \
        else
            mv $TMP_FILE $OUT_FILE
        fi
    else
        # 即便没有替换，也要原样输出一遍
        if [ "$OUT_FILE" = ".stdout" ]; then
            cat $TMP_FILE \
         && true; \
        fi
        rm $TMP_FILE
    fi
    if [ -f $TMP_FILE.stdin ]; then rm $TMP_FILE.stdin; fi
}
function __test_envsubst_enh() {
    local err_cnt=0
    local AAA=bye
    local TMP_DIR=${TMP_DIR:-/tmp}

    # 输入从stdin，输出是stdout
    local line=`echo 'hello $AAA' | envsubst_enh`
    [ "$line" = "hello bye" ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 1.1: $line";
    }

    # 输入是stdin，输出是文件
    local tmp_f=`mktemp ${TMP_DIR}/XXXXXX`
    echo 'hello $AAA' | envsubst_enh - $tmp_f
    line=$(<$tmp_f)
    [ "$line" = "hello bye" ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 1.2: $line";
    }
    rm -f $tmp_f

    # 输入是文件，输出是文件
    local tmp_f=`mktemp ${TMP_DIR}/XXXXXX`
    echo 'hello $AAA' >$tmp_f.in
    envsubst_enh $tmp_f.in $tmp_f
    rm -f $tmp_f.in
    line=$(<$tmp_f)
    [ "$line" = "hello bye" ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 1.3: $line";
    }
    rm -f $tmp_f

    # 输入是文件，输出是stdout
    local tmp_f=`mktemp ${TMP_DIR}/XXXXXX`
    echo 'hello $AAA' >$tmp_f.in
    line=`envsubst_enh $tmp_f.in`
    rm -f $tmp_f.in
    [ "$line" = "hello bye" ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 1.4: $line";
    }
    rm -f $tmp_f

    # test pipe接力
    echo 'hello $AAA' | envsubst_enh | grep -sqF "hello bye" || {
        ((err_cnt+=1)); log_error "Fail sub-case 1.5";
    }

    # 没有替换的话，也是要有输出的
    echo "hello world" | envsubst_enh | grep -sqF "hello world" || {
        ((err_cnt+=1)); log_error "Fail sub-case 1.6";
    }
    test $err_cnt -eq 0
}
function get_addr_by_name() {
    local _endpoint=${1:-`hostname -s`} && \
    local _ip_addr=`getent hosts ${_endpoint} ${_endpoint}. | grep "^[1-9]" | awk '{print $1}' | head -n1` && \
    if [ -z "${_ip_addr}" ]; then true \
     && log_error "Cannot resolve endpoint/\"${_endpoint}\" name to ip address. Abort!" \
     && false; \
    fi && \
    local _ip_ifac=`ip addr show | grep -F "${_ip_addr}" | sed -e 's/^.* \+//g'` && \
    if [ -z "${_ip_ifac}" ]; then true \
     && log_error "Cannot locate endpoint/\"${_endpoint}\" major ethernet interface. Abort!" \
     && getent hosts | while read LINE; do log_info ">> [hosts]: ${LINE}"; done \
     && ip addr show | while read LINE; do log_info ">> [ip_addr]: ${LINE}"; done \
     && false; \
    fi && \
    local _l2_addr=`ip link show dev ${_ip_ifac} | grep "link\/ether" | awk '{print $2}'` && \
    if [ -z "${_l2_addr}" ]; then true \
     && log_error "Cannot locate endpoint/\"${_endpoint}\" major ethernet address. Abort!" \
     && ip link show | while read LINE; do log_info ">> [ip_link]: ${LINE}"; done \
     && false; \
    fi && \
    echo "${_endpoint} ${_ip_addr} ${_l2_addr}" && \
    true
}
function git_token_wrapped() {
    true \
 && if [ -n "${BITBUCKET_ACCESS_TOKEN}" ] && echo "$@" | grep -sq "bitbucket\."; then true \
     && exec git -c "http.extraHeader=Authorization: Bearer $BITBUCKET_ACCESS_TOKEN" $@ \
     && true; \
    fi \
 && true; \
}
function get_host_key() {
    local _endpoint=${1:-${_endpoint:-${endpoint:-`hostname -s`}}} && \
    local _host_key_use_ip_addr=${2:-${_host_key_use_ip_addr:-${host_key_use_ip_addr:-false}}} && \
    local _show_qrcode=${3:-${_show_qrcode:-${show_qrcode:-true}}} && \
    local -a _rec=(`get_addr_by_name ${_endpoint}`) && \
    if [ ${#_rec[@]} -ne 3 ]; then true \
     && log_error "Fail to calculate host_key for endpoint \"${_endpoint}\". Abort!" >&2 \
     && false; \
    fi && \
    _endpoint=${_rec[0]} && \
    if [ "x$_host_key_use_ip_addr" == "xtrue" ]; then true \
     && local _ip_addr=${_rec[1]} \
     && true; \
    else true \
     && local _ip_addr="0.0.0.0" \
     && true; \
    fi && \
    local _l2_addr=${_rec[2]} && \
    local _host_key=`printf "%s" "['${_endpoint}', '${_ip_addr}', '${_l2_addr}']" | sha1sum -b | awk '{print $1}'` && \
    if [ -z "${_host_key}" ]; then true \
     && false; \
    fi && \
    local line="[\"${_host_key}\", \"${_endpoint}\"]" && \
    echo "$line" && \
    if [ "x${_show_qrcode}" == "xtrue" -a "x`command -v qrencode`" != "x" ]; then true \
     && echo "${line}" | qrencode -t ANSIUTF8 \
     && true; \
    fi && \
    true
}
function rsh_by_sudoer() {
    true \
 && local _target=${1} \
 && test -n "${_target}" && shift \
 && local _sudoer=${1} \
 && test -n "${_sudoer}" && shift \
 && local _user=${1} \
 && test -n "${_user}" && shift \
 && if [ "x${1}" == "x--" ]; then shift; fi \
 && test -n "${_sudoer_password}" \
 && { echo '
set timeout 20
spawn ssh '"${_target}"' -l'"${_sudoer}"' sudo -u '"${_user}"' -S <<< '"${_sudoer_password}"' bash -x -c '"'"''"true && $@"''"'"'
expect {
  "password:" { send "'"${_sudoer_password}"'\r"; exp_continue }
}
'
} | expect -f - \
 && true;
}
function uniq_and_count() { sort | awk '
    BEGIN { last=""; count=0; }
    NR == 1 { last=$0; count+=1; next; }
    {
        if ($0 == last) { count+=1; } else { print count" "last; last=$0; count=1; }
    }
    END { if (count>0) { print count" "last; }; }
'; }
function run_initialize_ops() {
    for_each_op eval ${G_registered_initialize_op[@]}
}
#-------------------------------------------------------------------------------
# utility functions initialize op
function _initialize_op_ohth3foo3zaisi7Phohwieshi9cahzof() {
    # ignore this op if it has not been registered
    if ! echo "${G_registered_initialize_op[@]}" | grep -sq "${FUNCNAME[0]}"; then
        return 0
    fi && \

    # make sure the env's locale is correct!!!
    setup_locale && \

    setup_os_flags && \

    setup_gnu_utils && \

    declare -g DEFAULT_use_conda=${use_conda:-${DEFAULT_use_conda:-true}} && \
    declare -g DEFAULT_sudo=${sudo:-${DEFAULT_sudo:-sudo}} && \
    if [ "${USER:-`whoami`}" = "root" ]; then DEFAULT_sudo=""; fi && \
    declare -g DEFAULT_as_root=${as_root:-${DEFAULT_as_root:-false}} && \

    #-------------------------------------------------------------------------------
    # Setup conda related global variables/envs
    declare -g G_conda_bin=${G_conda_bin:-`command -v conda`} && \
    declare -ag G_conda_install_flags=${G_conda_install_flags:-()} && \
    # cache变量，提升性能
    declare -gx G_conda_c_info_s=${G_conda_c_info_s} && \
    declare -gx G_conda_c_info_json=${G_conda_c_info_json} && \
    setup_conda_flags && \

    declare -ag G_apt_install_flags=${G_apt_install_flags:-()} && \
    setup_apt_flags && \

    #-------------------------------------------------------------------------------
    # Setup pip related global variables/envs
    declare -g G_python_bin=${G_python_bin:-`command -v python3`} && \
    declare -g G_pip_bin=${G_pip_bin:-""} && \
    declare -ag G_pip_install_flags=${G_pip_install_flags:-()} && \
    declare -ag G_pip_list_flags=${G_pip_list_flags:-()} && \
    declare -g G_python_ver=${G_python_ver:-""} && \
    declare -g G_python_ver_major=${G_python_ver_major:-""} && \
    declare -g G_python_ver_minor=${G_python_ver_minor:-""} && \
    setup_pip_flags && \

    #-------------------------------------------------------------------------------
    # Setup yum related global variables/envs
    declare -ag G_yum_flags=${G_yum_flags:-()} && \

    # un-register itself after it had been executed successfully
    declare -a _delete=("${FUNCNAME[0]}") && \
    G_registered_initialize_op=(${G_registered_initialize_op[@]}/${_delete})
}
# Register util's initialize_op
if ! declare -a | grep -sq "^declare -a G_registered_initialize_op="; then
    declare -ag G_registered_initialize_op=("_initialize_op_ohth3foo3zaisi7Phohwieshi9cahzof")
elif ! echo "${G_registered_initialize_op[@]}" | grep -sq "_initialize_op_ohth3foo3zaisi7Phohwieshi9cahzof"; then
    G_registered_initialize_op+=("_initialize_op_ohth3foo3zaisi7Phohwieshi9cahzof")
fi
#
# end of utility functions
#-------------------------------------------------------------------------------



#-------------------------------------------------------------------------------
#
# begin of feature functions
#
function install_anaconda() {
    local python_ver_major=${python_ver_major:-"3"}
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    print_title "Install Anaconda${python_ver_major} installer's dependency" | log_lines debug && \
    declare -a pkgs=() && \
    if ! $is_osx; then
        pkgs+=("bzip2")
        if do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' "true"; then
            pkg_list_installed ${pkgs[@]}
        else
            log_error "Fail to install anaconda installer's dependent pkgs \"`filter_pkgs ${pkgs[@]} | xargs`\""
            false
        fi
    fi && \

    print_title "Install Anaconda${python_ver_major}" | log_lines debug && \
    test -n "$conda_install_home" && \
    if do_and_verify \
        'eval bash -l -c "
              source $conda_install_home/etc/profile.d/conda.sh &&
              conda info -s 2>&1 | grep -sq \"^sys.prefix: $conda_install_home\""' \
        'eval unset PYTHONPATH &&
              f=`download_by_cache $conda_installer_url` &&
              $_sudo bash $f -b -p $conda_install_home &&
              if [ -n "$_sudo" ]; then
                  $_sudo ln -s $conda_install_home/etc/profile.d/conda.sh /etc/profile.d/;
              fi &&
              setup_conda_flags' \
        "true"; then
        ${G_conda_bin} info | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to install Anaconda${python_ver_major} \"`basename $conda_installer_url`\""
        if [ -d ${conda_install_home}.fail ]; then rm -rf ${conda_install_home}.fail; fi
        mv $conda_install_home $conda_install_home.fail
        false
    fi
}
function conda_create_env() {
    local _user=false
    if [ "$1" = "--user" ]; then _user=true; shift; fi
    local _ve_name=""
    local _ve_prefix=""
    if [ "$1" = "--name" ]; then
        _ve_name=$2; shift 2
    elif [ `$G_expr_bin "#$1" : "^#--name="` -eq 8 ]; then
        _ve_name="${1/--name=}"; shift
    elif [ "$1" = "--prefix" ]; then
        _ve_prefix=$2; shift 2
    elif [ `$G_expr_bin "#$1" : "^#--prefix="` -eq 10 ]; then
        _ve_prefix="${1/--prefix=}"; shift
    else
        _ve_name=$conda_env_name
    fi
    local _env_activated=false
    if [ -n "$_ve_prefix" ]; then
        if [ "$_ve_prefix" = "$CONDA_PREFIX" ]; then
            _env_activated=true
        fi
        _ve_name=`basename $_ve_prefix`
        _envs_dir=`dirname $_ve_prefix`
        env_arg_name="prefix"
    else
        if [ "$_ve_name" = "$CONDA_DEFAULT_ENV" ]; then
            _env_activated=true
        fi
        env_arg_name="name"
    fi
    local extra_args=$@

    print_title "Install Anaconda${python_ver_major} environment \"${_ve_name}\"" | log_lines debug && \

    # deactivate self VE first to prevent an internal error from conda>=4.6 before setting up itself.
    if $_env_activated; then
        _shadow_cmd_conda deactivate
    fi && \

    # install conda VE
    if do_and_verify \
        'eval ${G_conda_bin} env list | grep -Esq "^${_ve_name} +|^base +.*\/${_ve_name}$|^ +${_envs_dir:+${_envs_dir}/}${_ve_name}$"' \
        'eval if ! ${_user}; then _prefix=${sudo:+"${sudo} -i"}; fi; ${_prefix}${G_conda_bin} create --$env_arg_name ${_envs_dir:+${_envs_dir}/}${_ve_name} --yes ${G_conda_install_flags[@]} $extra_args pip' \
        'true'; then
        {
            ${G_conda_bin} env list | grep -E "^${_ve_name} *|\/${_ve_name}$"
            ${G_conda_bin} list --$env_arg_name ${_envs_dir:+${_envs_dir}/}${_ve_name}
        } | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to create conda environment \"$_ve_name\""
        false
    fi && \

    # re-activate self VE
    if $_env_activated; then
        _shadow_cmd_conda activate ${_envs_dir:+${_envs_dir}/}${_ve_name}
    fi
}
function get_conda_env_prefixed_name() {
    if declare -F conda >/dev/null; then
        cache_conda_info_s && \
        conda_install_home=`echo "$G_conda_c_info_s" | grep ^sys.prefix: | awk '{print $2}'`
    fi
    local _ve_prefix=${1:-${CONDA_DEFAULT_ENV}}
    local _ve_name=""

    if echo "$_ve_prefix" | grep -sqE "^\/|^\."; then
        _ve_name=`basename $_ve_prefix`
        _ve_prefix=`dirname $_ve_prefix`

    elif [ "$_ve_prefix" = "base" -o "$_ve_prefix" = "$conda_install_home" ]; then
        _ve_prefix=$conda_install_home

    else
        _ve_name=$_ve_prefix
        # >> #
        # >> # conda environments:
        # >> #
        # >> darwin_cpu               /u/fuzhiwen/.conda/envs/darwin_cpu
        # >> darwin_gpu               /u/fuzhiwen/.conda/envs/darwin_gpu
        # >> base                  *  /u/fuzhiwen/.conda/envs/darwin_gpu_nomkl
        # >> darwin_mkl               /u/fuzhiwen/.conda/envs/darwin_mkl
        # >>                          /u/fuzhiwen/anaconda3
        _ve_prefix=`_shadow_cmd_conda env list | grep "\/${_ve_name}$" | sed -e 's,^.* \/,\/,' | head -n1`
        _ve_prefix=`dirname $_ve_prefix`
    fi
    if [ -n "$_ve_prefix" -a -z "$_ve_name" ]; then
        echo "$_ve_prefix"
    elif [ -n "$_ve_prefix" -a -n "$_ve_name" ]; then
        echo "$_ve_prefix/$_ve_name"
    else
        false
    fi
}
function __test_get_conda_env_prefixed_name() {
    local err_cnt=0

    #
    # "base" ve is special
    #
    local r="`get_conda_env_prefixed_name base`"
    [ "$r" = "$conda_install_home" ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 1: detect base ve as \"$r\"";
    }

    local conda_envs=`_shadow_cmd_conda env list | sed -e 's/ \* / /g' | grep -vE "^#|^ *\/" | tr -s ' '`
    echo "$conda_envs" | sed -e 's/^/>> [conda env list]: /g' | log_lines debug
    local n_envs=`echo "$conda_envs" | wc -l | awk '{print $1}'`

    #
    # a named ve can be detected
    #
    for idx in `seq 1 $n_envs`
    do
        local ve_name=`echo "$conda_envs" | cut -d' ' -f1 | head -n$idx | tail -n1`
        local ve_prefix=`echo "$conda_envs" | cut -d' ' -f2 | head -n$idx | tail -n1`
        log_info "test_conda_env_prefixed_name sub case 2.$idx for ve \"$ve_name $ve_prefix\""

        local r1="`get_conda_env_prefixed_name $ve_name`"
        local r2="`get_conda_env_prefixed_name $ve_prefix`"
        [ "$r1" = "$ve_prefix" -a "$r1" = "$r2" ] || {
            ((err_cnt+=1)); log_error "Fail sub-case 2: detect named ve as \"$ve_prefix\" vs. \"$r1\" vs. \"$r2\"";
            break;
        }
    done

    #
    # still work with an env activated
    #
    if [ $n_envs -ge 2 ]; then
        local ve_prefix=`echo "$conda_envs" | cut -d' ' -f2 | head -n1 | tail -n1`
        conda_activate_env $ve_prefix

        local ve_name2=`echo "$conda_envs" | cut -d' ' -f1 | head -n2 | tail -n1`
        local ve_prefix2=`echo "$conda_envs" | cut -d' ' -f2 | head -n2 | tail -n1`

        local r1="`get_conda_env_prefixed_name $ve_name2`"
        local r2="`get_conda_env_prefixed_name $ve_prefix2`"
        [ "$r1" = "$ve_prefix2" -a "$r1" = "$r2" ] || {
            ((err_cnt+=1)); log_error "Fail sub-case 2: detect named ve as \"$ve_prefix2\" vs. \"$r1\" vs. \"$r2\"";
        }

        _shadow_cmd_conda deactivate
    fi

    test $err_cnt -eq 0
}
function get_conda_active_prefix() {
    # >> "active_prefix": "/u/fuzhiwen/.conda/envs/darwin_gpu_nomkl",
    # >> "conda_prefix": "/Users/fuzhiwen/anaconda3",
    # >> "default_prefix": "/Users/fuzhiwen/anaconda3",
    if [ -z "$G_conda_c_info_json" ]; then
        cache_conda_info_json
    fi
    local _lines=`echo "$G_conda_c_info_json" \
        | grep -E "\"active_prefix\":|\"#conda_prefix\":|\"#default_prefix\":" \
        | cut -d\" -f4 | grep -vE "^$|^null$"`

    if [ -n "$_lines" ]; then
        echo "$_lines" | head -n1
    else
        false
    fi
}
function __test_get_conda_active_prefix() {
    local err_cnt=0

    # deactivate all ve first
    _shadow_cmd_conda deactivate

    # explore all conda envs
    local conda_envs=`_shadow_cmd_conda env list | sed -e 's/ \* / /g' | grep -vE "^#|^ *\/" | tr -s ' '`
    echo "$conda_envs" | sed -e 's/^/[conda envs] >> /g' | log_lines debug
    local n_envs=`echo "$conda_envs" | wc -l | awk '{print $1}'`

    #
    # no ve activated means "base" activated, and will fail the call
    #
    get_conda_active_prefix && {
        ((err_cnt+=1)); log_error "Fail sub-case 1: no activate should fail the get_conda_activate_prefix";
    }

    #
    # no ve returns ""
    #
    local r="`get_conda_active_prefix`"
    [ -z "$r" ] || {
        ((err_cnt+=1)); log_error "Fail sub-case 2: no active should return null, instead of \"$r\"";
    }

    #
    # can detect explicitly activated ve
    #
    for idx in `seq 1 $n_envs`
    do
        local ve_name=`echo "$conda_envs" | cut -d' ' -f1 | head -n$idx | tail -n1`
        local ve_prefix=`echo "$conda_envs" | cut -d' ' -f2 | head -n$idx | tail -n1`
        log_info "test_get_conda_active_prefix sub case 3.$idx for ve \"$ve_name $ve_prefix\""

        local r="`get_conda_active_prefix`"
        [ -z "$r" ] || {
            ((err_cnt+=1)); log_error "Fail sub-case 3.$idx.0: base should be the active prefix when none activated, as \"$r\"";
            break
        }

        conda_activate_env $ve_prefix

        local r="`get_conda_active_prefix`" && \
        if [ "$r" != "$ve_prefix" ]; then
            ((err_cnt+=1)); log_error "Fail sub-case 3.$idx.1: detect explicitly activated ve \"$ve_prefix\" vs. \"$r\"";
            break
        fi

        _shadow_cmd_conda deactivate
    done

    test $err_cnt -eq 0
}
function is_conda_env_activated() {
    local _ve_prefix=`get_conda_env_prefixed_name $1`
    local _active_prefix=`get_conda_active_prefix`

    # strict check if conda env had been activated or not
    test "$_ve_prefix" = "$_active_prefix" -a "`command -v python`" = "$_active_prefix/bin/python"
}
function __test_is_conda_env_activated() {
    local err_cnt=0

    # deactivate any pre ve first
    _shadow_cmd_conda deactivate

    # explore all conda envs
    local conda_envs=`_shadow_cmd_conda env list | sed -e 's/ \* / /g' | grep -vE "^#|^ *\/" | tr -s ' '`
    echo "$conda_envs" | log_lines debug
    local n_envs=`echo "$conda_envs" | wc -l | awk '{print $1}'`

    #
    # try every existing ve
    #
    local -a ve_prefixes=(`echo "$conda_envs" | cut -d' ' -f2`)
    ve_prefixes+=("base")

    local icnt=1
    for ve_prefix in ${ve_prefixes[@]}
    do
        log_debug "test_is_conda_env_activated sub-case 1.$icnt: ve_prefix is \"$ve_prefix\""

        local ve_prefix="`get_conda_env_prefixed_name $ve_prefix`"
        is_conda_env_activated $ve_prefix && {
            ((err_cnt+=1)); log_error "Fail sub-case 1.1: detect if base ve was activated";
            break;
        }

        conda_activate_env $ve_prefix
        if [ "$ve_prefix" != "$conda_install_home" -a "$ve_prefix" != "base" ]; then
            is_conda_env_activated "base" && {
                ((err_cnt+=1)); log_error "Fail sub-case 1.misc: base should not be detected as activated";
                break;
            }
        fi

        is_conda_env_activated $ve_prefix || {
            ((err_cnt+=1)); log_error "Fail sub-case 1.2: detect if base ve was activated";
            break;
        }

        _shadow_cmd_conda deactivate
        ((icnt+=1))
    done

    test $err_cnt -eq 0
}
function conda_activate_env() {
    local _ve_prefix=`get_conda_env_prefixed_name $1`
    if is_conda_env_activated $_ve_prefix && [ "$always_force_activating_conda_env" = "false" ]; then
        log_debug "Conda env \"$_ve_prefix\" was already activated. Skip activating."
    else
        log_info "Activating conda env \"$_ve_prefix\""
        _shadow_cmd_conda activate $_ve_prefix && \
        true
    fi
}
function __test_conda_activate_env() {
    local err_cnt=0

    local conda=_shadow_cmd_conda

    # deactivate all conda ve first
    $conda deactivate

    # explore all conda envs
    local conda_envs=`$conda env list | sed -e 's/ \* / /g' | grep -vE "^#|^ *\/" | tr -s ' '`
    echo "$conda_envs" | log_lines debug
    local n_envs=`echo "$conda_envs" | wc -l | awk '{print $1}'`

    #
    # try activating each ve
    #
    for field_idx in 1 2
    do
        for ve_idx in `seq 1 $n_envs`
        do
            local ve_name=`echo "$conda_envs" | cut -d' ' -f1 | head -n$ve_idx | tail -n1`
            local ve_prefix=`echo "$conda_envs" | cut -d' ' -f2 | head -n$ve_idx | tail -n1`
            local ve_name_to_be_activated=""
            if [ $field_idx -eq 1 ]; then
                ve_name_to_be_activated=$ve_name
            else
                ve_name_to_be_activated=$ve_prefix
            fi
            log_info "test_conda_activate_env sub case 1.$ve_idx for ve \"$ve_name $ve_prefix\""

            is_conda_env_activated $ve_name_to_be_activated && {
                ((err_cnt+=1)); log_error "Fail sub-case 1.1.$field_idx.$ve_idx: check in-activate bef activating per ve \"$ve_name_to_be_activated\""
                break;
            }
            conda_activate_env $ve_name_to_be_activated || {
                ((err_cnt+=1)); log_error "Fail sub-case 1.2.$field_idx.$ve_idx: check activating rc per ve \"$ve_name_to_be_activated\""
                break;
            }
            is_conda_env_activated $ve_name_to_be_activated || {
                ((err_cnt+=1)); log_error "Fail sub-case 1.3.$field_idx.$ve_idx: check is-activated aft activating per ve \"$ve_name_to_be_activated\""
                break;
            }
            _shadow_cmd_conda deactivate
        done
    done

    test $err_cnt -eq 0
}
DEFAULT_python_ver_major=${DEFAULT_python_ver_major:-${python_ver_major:-"3"}}
DEFAULT_conda_install_home=${DEFAULT_conda_install_home:-"$HOME/anaconda${DEFAULT_python_ver_major}"}
DEFAULT_conda_env_name=${DEFAULT_conda_env_name:-"base"}
DEFAULT_conda_envs_dir=${DEFAULT_conda_envs_dir:-"$HOME/.conda/envs"}
# https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH:-`uname -m`}.sh
DEFAULT_conda_installer_url=${DEFAULT_conda_installer_url:-"https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-${ARCH:-`uname -m`}.sh"}
DEFAULT_always_force_activating_conda_env=${DEFAULT_always_force_activating_conda_env:${always_force_activating_conda_env:-true}}
function install_nginx_prereqs_on_ubuntu() {
    local -a pkgs=(
        "deb:ca-certificates"
        "deb:curl"
        "deb:gnupg2"
        "deb:lsb-release"
        "deb:software-properties-common"
    )
    if do_and_verify \
        'eval pkg_verify ${pkgs[@]}' \
        'eval pkg_install ${pkgs[@]}' \
        "true"; then
        pkg_list_installed ${pkgs[@]} | log_lines debug
    else
        log_error "Fail to install nginx prereqs \"${pkgs[@]}\" on ubuntu"
        false
    fi
}
#
# deprecated by "setup_ubuntu_apt_repo_for_nginx_stable"
#
#function _setup_ubuntu_apt_repo_for_nginx_stable_legacy() {
#    # refer to detailed instruction from nginx official web site:
#    # >> http://nginx.org/en/linux_packages.html
#    install_nginx_prereqs_on_ubuntu && \
#    if ! do_and_verify \
#        "test -s /etc/apt/sources.list.d/nginx.list" \
#        'eval echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | $sudo tee /etc/apt/sources.list.d/nginx.list' \
#        'true'; then
#        #echo "deb http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | $sudo tee /etc/apt/sources.list.d/nginx.list && \
#        log_error "Fail to setup apt source for nginx"
#        false
#    fi && \
#    if do_and_verify \
#        'eval apt-key fingerprint ABF5BD827BD9BF62 | grep -sqi "ABF5 BD82"' \
#        'eval curl -fsSL https://nginx.org/keys/nginx_signing.key | $sudo apt-key add -' \
#        'true'; then
#        # pub   rsa2048 2011-08-19 [SC] [expires: 2024-06-14]
#        #  573B FD6B 3D8F BC64 1079  A6AB ABF5 BD82 7BD9 BF62
#        #  uid           [ unknown] nginx signing key <signing-key@nginx.com>
#        apt-key fingerprint ABF5BD827BD9BF62 | log_lines debug
#    else
#        log_error "Fail to setup nginx apt key"
#        false
#    fi && {
#        $sudo apt-get update || true
#    } && \
#    true
#}
function setup_ubuntu_apt_repo_for_nginx_stable() {
    # https://launchpad.net/~nginx/+archive/ubuntu/stable
    # --------------------------------------------------------------------------------
    # PPA description
    # This PPA contains the latest Stable Release version of the nginx web server software.
    #
    # **Only Non-End-of-Life Ubuntu Releases are supported in this PPA**
    #
    # **Development releases of Ubuntu are not officially supported by this PPA, and uploads for those will not be available until Beta releases for those versions**
    #
    install_nginx_prereqs_on_ubuntu && \
    if do_and_verify \
        'eval apt-key fingerprint 00A6F0A3C300EE8C | grep -sqi "00A6 F0A3 C300 EE8C"' \
        'eval $sudo add-apt-repository -y ppa:nginx/stable' \
        'true'; then
        # /etc/apt/trusted.gpg.d/nginx_ubuntu_stable.gpg
        # ----------------------------------------------
        # pub   1024R/C300EE8C 2010-07-21
        #       Key fingerprint = 8B39 81E7 A685 2F78 2CC4  9516 00A6 F0A3 C300 EE8C
        #       uid                  Launchpad Stable
        apt-key fingerprint 00A6F0A3C300EE8C | log_lines debug
    else
        log_error "Fail to setup nginx apt key"
        false
    fi && {
        $sudo apt-get update || true
    } && \
    true
}
function install_nginx_prereqs_on_rhel() {
    local -a pkgs=(
        "rpm:yum-utils"
    )
    if do_and_verify \
        'eval pkg_verify ${pkgs[@]}' \
        'eval pkg_install ${pkgs[@]}' \
        'true'; then
        pkg_list_installed ${pkgs[@]} | log_lines debug
    else
        log_error "Fail to install nginx prereqs \"${pkgs[@]}\" on rhel"
        false
    fi
}
function setup_rhel_yum_repo_for_nginx_stable() {
    # refer to detailed instruction from nginx official web site:
    # >> http://nginx.org/en/linux_packages.html
    local ftmp=`mktemp /tmp/XXXXXXXX`

    install_nginx_prereqs_on_rhel && \
    echo '
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
' | sed -e "s/^ *//g" >$ftmp && \
    if do_and_verify \
        'eval $sudo yum-config-manager nginx-stable | grep -sq "\[nginx-stable\]"' \
        'eval $sudo cp $ftmp /etc/yum.repos.d/nginx.repo'
        'true'; then
        $sudo yum-config-manager nginx-stable | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to setup yum source for stable nginx"
        false
    fi && {
        # actively trigger repo update
        $sudo yum repolist || true
    } && \
    true

    local rc=$?
    #[ -s $ftmp ] && rm -f $ftmp
    (exit $rc)
}
function install_stable_nginx() {
    if $is_rhel; then true \
     && setup_rhel_yum_repo_for_nginx_stable \
     && true;
    elif $is_ubuntu; then true \
     && setup_ubuntu_apt_repo_for_nginx_stable \
     && true;
    fi && \
    local -a pkgs=(
        "nginx"
        "deb:libnginx-mod-http-lua"
    ) && \
    if do_and_verify \
        'eval pkg_verify ${pkgs[@]}' \
        'eval pkg_install ${pkgs[@]}' \
        "true"; then
        pkg_list_installed ${pkgs[@]} | log_lines debug || true
    else
        log_error "Fail to install nginx"
        false
    fi
}
function install_docker() {
    # https://get.docker.com/
    # >> # This script is meant for quick & easy install via:
    # >> #   $ curl -fsSL https://get.docker.com -o get-docker.sh
    # >> #   $ sh get-docker.sh
    # >> #
    # >> # For test builds (ie. release candidates):
    # >> #   $ curl -fsSL https://test.docker.com -o test-docker.sh
    # >> #   $ sh test-docker.sh
    # >> #
    # >> # NOTE: Make sure to verify the contents of the script
    # >> #       you downloaded matches the contents of install.sh
    # >> #       located at https://github.com/docker/docker-install
    # >> #       before executing.
    # >> # Git commit from https://github.com/docker/docker-install when
    # >> # the script was uploaded (Should only be modified by upload job):
    # >> SCRIPT_COMMIT_SHA="f45d7c11389849ff46a6b4d94e0dd1ffebca32c1"
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    local _get_docker_sh=`mktemp /tmp/XXXXXXXX`
    local _enforce=${enforce:-false}
    if do_and_verify \
        'eval command -v docker >/dev/null && test "$_enforce" = "false"' \
        'eval true
           && curl ${CURL_PROXY:+--proxy} ${CURL_PROXY} -fsSL https://get.docker.com -o $_get_docker_sh
           && test -s $_get_docker_sh
           && $sudo sh $_get_docker_sh' \
        'eval _enforce=false'; then
       {
           command -v docker
           docker version
           docker info
       } 2>&1 | \
       sed -e 's/^/>> [docker]: /g' | \
       log_lines info
    else
        log_error "Fail to install docker"
        false
    fi
    local rc=$?
    rm -f $_get_docker_sh
    (exit $rc)
}
function install_docker_compose() {
    if $is_osx; then
        install_docker_compose_osx $@
    else
        install_docker_compose_linux $@
    fi
}
function install_docker_compose_osx() {
    brew install docker-compose
}
function install_docker_compose_linux() {
    # https://docs.docker.com/compose/install/
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    local _enforce=${enforce:-false}
    local docker_compose_url="https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)"
    local docker_compose_url="https://github.com/docker/compose/releases/download/2.26.1/docker-compose-$(uname -s)-$(uname -m)"
    if do_and_verify \
        'eval command -v docker-compose >/dev/null && test "$_enforce" = "false"' \
        'eval true
           && f=`download_by_cache $docker_compose_url`
           && $_sudo cp $f /usr/local/bin/
           && f=`basename $f`
           && $_sudo chmod a+rx /usr/local/bin/$f
           && $_sudo update-alternatives --install /usr/bin/docker-compose docker-compose /usr/local/bin/$f 10
           && true' \
        'eval _enforce=false'; then
       {
           command -v docker-compose
           docker-compose version
       } 2>&1 | \
       sed -e 's/^/>> [docker-compose]: /g' | \
       log_lines info
    else
        log_error "Fail to install docker-compose"
        false
    fi
    local rc=$?
}
function install_homebrew_mirror() {
    # https://developer.aliyun.com/mirror/
    # https://developer.aliyun.com/mirror/homebrew?spm=a2c6h.13651102.0.0.3e221b11OJ5itU
    # 替换brew.git:
    cd "$(brew --repo)"
    git remote set-url origin https://mirrors.aliyun.com/homebrew/brew.git
    # 替换homebrew-core.git:
    cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
    git remote set-url origin https://mirrors.aliyun.com/homebrew/homebrew-core.git
    # 应用生效
    brew update
    # 替换homebrew-bottles:
    echo 'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles' >> ~/.bash_profile
    source ~/.bash_profile
}
#
# install epel yum repo
#
DEFAULT_epel_url=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
function install_epel() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    # install epel repo
    # but disable it by default
    if $is_rhel && ! $_sudo yum list installed epel-release | grep -sq epel-release; then
        $_sudo yum install -y $epel_url && \
        true
    fi
}
function _switch_epel() {
    local on_off=$1
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    if $is_rhel && $_sudo yum list installed epel-release | grep -sq epel-release; then
        $_sudo sed -i -e 's/enabled=[01]/enabled='$on_off'/g' /etc/yum.repos.d/epel.repo
    fi
}
function enable_epel() { _switch_epel 1; }
function disable_epel() { _switch_epel 0; }
DEFAULT_remi_url=http://rpms.remirepo.net/enterprise/remi-release-7.rpm
# full mirror in CN: https://mirrors.tuna.tsinghua.edu.cn/remi/
function install_remi() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    # install epel repo
    # but disable it by default
    if $is_rhel && ! $_sudo yum list installed remi-release | grep -sq remi-release; then
        $_sudo yum install -y $remi_url && \
        true
    fi
}
function _switch_remi() {
    local on_off=$1
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    if $is_rhel && $_sudo yum list installed remi-release | grep -sq remi-release; then
        $_sudo sed -i -e 's/enabled=[01]/enabled='$on_off'/g' /etc/yum.repos.d/remi.repo
    fi
}
function enable_remi() { _switch_remi 1; }
function disable_remi() { _switch_remi 0; }
DEFAULT_rpmfusion_free_url="https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm"
function install_rpmfusion_free() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    # install rpmfusion-free repo
    # but disable it by default
    if $is_rhel && ! $_sudo yum list installed rpmfusion-free-release | grep -sq rpmfusion-free-release; then
        $_sudo yum install -y $rpmfusion_free_url && \
        true
    fi
}
function _switch_rpmfusion_free() {
    local on_off=$1
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    if $is_rhel && $_sudo yum list installed rpmfusion-free-release | grep -sq rpmfusion-free-release; then
        $_sudo sed -i -e 's/enabled=[01]/enabled='$on_off'/g' /etc/yum.repos.d/rpmfusion-free.repo
    fi
}
function enable_rpmfusion_free() { _switch_rpmfusion_free 1; }
function disable_rpmfusion_free() { _switch_rpmfusion_free 0; }
DEFAULT_rpmfusion_nonfree_url="https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm"
function install_rpmfusion_nonfree() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    # install rpmfusion-nonfree repo
    # but disable it by default
    if $is_rhel && ! $_sudo yum list installed rpmfusion-nonfree-release | grep -sq rpmfusion-nonfree-release; then
        $_sudo yum install -y $rpmfusion_nonfree_url && \
        true
    fi
}
function _switch_rpmfusion_nonfree() {
    local on_off=$1
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    if $is_rhel && $_sudo yum list installed rpmfusion-nonfree-release | grep -sq rpmfusion-nonfree-release; then
        $_sudo sed -i -e 's/enabled=[01]/enabled='$on_off'/g' /etc/yum.repos.d/rpmfusion-nonfree.repo
    fi
}
function enable_rpmfusion_nonfree() { _switch_rpmfusion_nonfree 1; }
function disable_rpmfusion_nonfree() { _switch_rpmfusion_nonfree 0; }
function install_centos7_repo() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    local releasever=7
    local f_repo=/etc/yum.repos.d/CentOS-Base.repo
    if [ ! -f $f_repo ]; then
        cat >$f_repo <<EOF
[base]
name=CentOS-$releasever - Base
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=\$basearch&repo=os&infra=\$infra
#baseurl=http://mirror.centos.org/centos/$releasever/os/\$basearch/
gpgcheck=1
#gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
gpgkey=http://mirror.centos.org/centos/7/os/x86_64/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-$releasever - Updates
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=\$basearch&repo=updates&infra=\$infra
#baseurl=http://mirror.centos.org/centos/$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/7/os/x86_64/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=\$basearch&repo=extras&infra=\$infra
#baseurl=http://mirror.centos.org/centos/$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/7/os/x86_64/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=\$basearch&repo=centosplus&infra=\$infra
#baseurl=http://mirror.centos.org/centos/$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirror.centos.org/centos/7/os/x86_64/RPM-GPG-KEY-CentOS-7
EOF
    fi
}
function install_cu102() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    function _install_cu102() {
        true \
     && if ! do_and_verify \
            "pkg_verify cuda-10-2" \
            "pkg_install cuda-10-2" \
            "true"; then true \
         && log_error "Fail to install cuda-10-2" \
         && false; \
        fi \
     && true;
    }

    true \
 && local distribution=$(. /etc/os-release; echo $ID$VERSION_ID) \
 && if [ "x${distribution}" = "xcentos7" ]; then true \
     && install_${distribution/./}_nvidia_repo_cu102 \
     && $_sudo apt-get update \
     && _install_cu102 \
     && true;
    elif [ "x${distribution}" = "xubuntu20.04" ]; then true \
     && install_${distribution/./}_nvidia_cu102 \
     && true;
    elif [ "x${distribution}" = "xubuntu18.04" ]; then true \
     && install_${distribution/./}_nvidia_repo_cu102 \
     && install_${distribution/./}_nvidia_ml_repo \
     && $_sudo apt-get update \
     && _install_cu102 \
     && true;
    fi \
 && true;
}
function install_ubuntu2004_nvidia_cu102() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && local _f_run_uri="ftp://10.209.16.37:10021/softwares/nvidia/cuda_10.2.89_min_linux.run" \
 && function _install() {
        true \
     && local _f_run=`download_by_cache $_f_run_uri` \
     && $_sudo bash ${_f_run} \
     && true;
    } \
 && if do_and_verify \
        "test -f /usr/local/cuda-10.2/include/cuda.h" \
        "_install" \
        "true"; then true \
     && true; \
    fi \
 && true; \
}
function _install_centos7_nvidia_repo_legacy() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    local version_id=$(. /etc/os-release; echo $VERSION_ID)
    local gpgkey_id=${gpgkey_id:-"D42D0685"}
    local f_repo=/etc/yum.repos.d/cuda-rhel${version_id}.repo
    if [ ! -f $f_repo ]; then true \
     && f_repo_url="https://developer.download.nvidia.com/compute/cuda/repos/rhel${version_id}/x86_64/cuda-rhel${version_id}.repo" \
     && f_repo_=`download_by_cache $f_repo_url` \
     && cat $f_repo_ | $_sudo tee $f_repo \
     && { cat <<EOF
[cuda]
name=cuda
baseurl=https://developer.download.nvidia.com/compute/cuda/repos/rhel${version_id}/x86_64
enabled=1
gpgcheck=1
gpgkey=https://developer.download.nvidia.com/compute/cuda/repos/rhel${version_id}/x86_64/${gpgkey_id}.pub
EOF
     } | $_sudo tee ${f_repo} \
     && $_sudo yum install -y cuda-repo-rhel${version_id} \
     && true; \
    fi
}
function _install_centos7_nvidia_repo() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    local version_id=$(. /etc/os-release; echo $VERSION_ID)
    # https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=CentOS&target_version=7&target_type=rpm_network
    # https://developer.nvidia.com/cuda-11.0-download-archive?target_os=Linux&target_arch=x86_64&target_distro=CentOS&target_version=7&target_type=rpmnetwork
    # https://developer.nvidia.com/cuda-10.2-download-archive?target_os=Linux&target_arch=x86_64&target_distro=CentOS&target_version=7&target_type=rpmnetwork
    #
    # sudo yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo
    #
    # sudo yum clean all
    # sudo yum -y install nvidia-driver-latest-dkms cuda
    # sudo yum -y install cuda-drivers
    true \
 && local f_repo_url="https://developer.download.nvidia.com/compute/cuda/repos/rhel${version_id}/x86_64/cuda-rhel${version_id}.repo" \
 && local f_repo=/etc/yum.repos.d/cuda-rhel${version_id}.repo \
 && function _install() {
        true \
     && local _f=`download_by_cache $f_repo_url` \
     && $_sudo yum-config-manager --add-repo $_f \
     && true;
    } \
 && if do_and_verify \
        "test -f $f_repo" \
        "_install" \
        "true"; then true \
     && true;
    fi \
 && log_info "Install \"cuda\" by running: yum clean all && yum install nvidia-driver-latest-dkms cuda && yum install cuda-drivers" \
 && true;
}
function install_centos7_nvidia_repo_cu102() {
    true \
 && _install_centos7_nvidia_repo \
 && true;
}
function install_centos7_nvidia_repo_cu110() {
    true \
 && _install_centos7_nvidia_repo \
 && true;
}
function install_centos7_nvidia_repo_cu120() {
    true \
 && _install_centos7_nvidia_repo \
 && true;
}
function install_centos7_nvidia_ml_repo() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    local version_id=$(. /etc/os-release; echo $VERSION_ID)
    local gpgkey_id=${gpgkey_id:-"7fa2af80"}
    local f_repo="/etc/yum.repos.d/nvidia-machine-learning.repo"
    if [ ! -f $f_repo ]; then true \
     && { cat <<EOF
[nvidia-machine-learning]
name=nvidia-machine-learning
baseurl=http://developer.download.nvidia.com/compute/machine-learning/repos/rhel${version_id}/x86_64/
enabled=1
gpgcheck=1
gpgkey=http://developer.download.nvidia.com/compute/machine-learning/repos/rhel${version_id}/x86_64/${gpgkey_id}.pub
EOF
     } | $_sudo tee ${f_repo} \
     && $_sudo yum install -y nvidia-machine-learning-repo-rhel${version_id} \
     && true; \
    fi
}
function install_cuda_toolkit_repo_ubuntu() {
    true set -x \
 && local _key=`grep -E "^ID=|^VERSION_ID=" /etc/os-release | sort | cut -d= -f2 | xargs | sed -e 's/ *//g' -e 's/\.//g' -e 's/"//g'` \
 && _install_cuda_toolkit_repo_${_key} $@ \
 && true; \
}
function _install_cuda_toolkit_repo_ubuntu2004() {
    true set -x \
 && local _sudo=${_sudo:-${sudo:-/usr/bin/sudo}} \
 && if [ "x${as_root}" != "xtrue" ]; then _sudo=""; fi \
 && local _pkg_keyring_f_url=${_pkg_keyring_f_url:-https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb} \
 && local _pkg_keyring=`download_by_cache ${_pkg_keyring_f_url}` \
 && ${_sudo} dpkg -i ${_pkg_keyring} \
 && ${_sudo} apt-get update \
 && true; \
}
function _install_cuda_toolkit_repo_ubuntu2204() {
    true set -x \
 && local _pkg_keyring_f_url=${_pkg_keyring_f_url:-https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb} \
 && install_cuda_toolkit_repo_ubuntu2004 $@ \
 && true; \
}
function _install_cuda_toolkit_repo_ubuntu2404() {
    true set -x \
 && local _pkg_keyring_f_url=${_pkg_keyring_f_url:-https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb} \
 && install_cuda_toolkit_repo_ubuntu2004 $@ \
 && true; \
}
function _install_ubuntu_nvidia_repo_deprecated() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    local distribution=$(. /etc/os-release; echo $ID$VERSION_ID)

    # https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/
    # 导入我们的 GPG 密钥：
    local aptkey_id=${aptkey_id:-"3bf863cc"}
    local aptkey_id_fmt=`echo ${aptkey_id} | tr 'a-z' 'A-Z' | sed -e 's/\(.\{4\}\)\(.*\)/\1 \2/g'`
    local aptkey_url="https://developer.download.nvidia.com/compute/cuda/repos/${distribution/./}/x86_64/${aptkey_id}.pub"
    local f_aptkey=`download_by_cache ${aptkey_url}`
    if do_and_verify \
        'eval apt-key fingerprint ${aptkey_id} | grep -sqi "${aptkey_id_fmt}"' \
        'eval curl ${CURL_PROXY:+--proxy} ${CURL_PROXY} -fsSL ${aptkey_url} | $_sudo apt-key add -' \
        'true'; then
        # 'eval $_sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "0x3BF863CC"' \
        # pub   rsa4096 2022-04-14 [SC]
        #       EB69 3B30 35CD 5710 E231  E123 A4B4 6996 3BF8 63CC
        # uid           [ unknown] cudatools <cudatools@nvidia.com>
        apt-key fingerprint ${aptkey_id} | log_lines debug
    else
        log_error "Fail to setup nvidia apt key"
        false
    fi

    local f_repo="/etc/apt/sources.list.d/cuda.list"
    function _install() {
        {
            echo "deb https://developer.download.nvidia.com/compute/cuda/repos/${distribution/./}/x86_64 /"
        } | $_sudo tee $f_repo >/dev/null
    }
    if do_and_verify \
        "test -f $f_repo" \
        '_install' \
        'true'; then true \
     && cat $f_repo | log_lines debug \
     && true; \
    else true \
     && log_error "Fail to install nvidia apt source" \
     && false; \
    fi && \
    true
}
function install_ubuntu2004_nvidia_repo_cu120() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    local distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
    # https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=20.04&target_type=deb_network
    #
    # wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
    # sudo dpkg -i cuda-keyring_1.0-1_all.deb
    #
    # sudo apt-get update
    # sudo apt-get -y install cuda
    true \
 && true  f_repo_pkg_url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb" \
 && local f_repo_pkg_url="https://developer.download.nvidia.com/compute/cuda/repos/${distribution/./}/x86_64/cuda-keyring_1.0-1_all.deb" \
 && function _install() {
        true \
     && local _f=`download_by_cache $f_repo_pkg_url` \
     && $_sudo dpkg -i $_f \
     && true;
    } \
 && if do_and_verify \
        "pkg_verify_deb cuda-keyring" \
        "_install" \
        "true"; then true \
     && dpkg -L cuda-keyring | log_lines debug \
     && true; \
    else true \
     && log_error "Fail to install cuda-keyring for nvidia repo" \
     && false; \
    fi \
 && log_info "Install \"cuda\" by running: apt-get update && apt-get -y install cuda" \
 && true;
}
function install_ubuntu1804_nvidia_repo_cu120() {
    true \
 && install_ubuntu2004_nvidia_repo_cu120 \
 && true;
}
function install_ubuntu2004_nvidia_repo_cu110() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    local distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
    local aptkey_id=${aptkey_id:-"7fa2af80"}
    # https://developer.nvidia.com/cuda-11.0-download-archive?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=2004&target_type=debnetwork
    #
    # wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
    # sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
    #
    # sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub
    # sudo add-apt-repository "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"
    #
    # sudo apt-get update
    # sudo apt-get -y install cuda
    true \
 && true \
 && true "Pin the cuda repo" \
 && true \
 && true  f_pin_url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin" \
 && local f_pin_url="https://developer.download.nvidia.com/compute/cuda/repos/${distribution/./}/x86_64/cuda-${distribution/./}.pin" \
 && local f_pin="/etc/apt/preferences.d/cuda-repository-pin-600" \
 && function _install() {
        true \
     && local _f_pin=`download_by_cache $f_pin_url` \
     && $_sudo mkdir -p `dirname $f_pin` \
     && $_sudo cp $_f_pin $f_pin \
     && true;
    } \
 && if do_and_verify \
        "test -f $f_pin" \
        "_install" \
        "true"; then true \
     && true; \
    fi \
 && true \
 && true "Configure the cuda repo" \
 && true \
 && _install_ubuntu_nvidia_repo \
 && true \
 && log_info "Install \"cuda\" by running: apt-get update && apt-get -y install cuda" \
 && true;
}
function install_ubuntu1804_nvidia_repo_cu110() {
    true \
 && install_ubuntu2004_nvidia_repo_cu110 \
 && true;
}
function install_ubuntu1804_nvidia_repo_cu102() {
    # https://developer.nvidia.com/cuda-10.2-download-archive?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=1804&target_type=debnetwork
    #
    # wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin
    # sudo mv cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600
    #
    # sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
    # sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /"
    #
    # sudo apt-get update
    # sudo apt-get -y install cuda
    true \
 && install_ubuntu2004_nvidia_repo_cu110 \
 && true;
}
function install_ubuntu2004_nvidia_docker_repo() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    # 导入我们的 GPG 密钥：
    local gpgkey_url="https://nvidia.github.io/nvidia-docker/gpgkey"
    if do_and_verify \
        'eval apt-key fingerprint F796ECB0 | grep -sqi "F796 ECB0"' \
        'eval curl ${CURL_PROXY:+--proxy} ${CURL_PROXY} -fsSL ${gpgkey_url} | $_sudo apt-key add -' \
        'true'; then
        # pub   rsa4096 2017-09-28 [SCE]
        #       C95B 321B 61E8 8C18 09C4  F759 DDCA E044 F796 ECB0
        #       uid           [ unknown] NVIDIA CORPORATION (Open Source Projects) <cudatools@nvidia.com>
        apt-key fingerprint F796ECB0 | log_lines debug
    else
        log_error "Fail to setup nvidia docker apt key"
        false
    fi

    local f_repo="/etc/apt/sources.list.d/nvidia-docker.list"
    function _install() {
        local distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
        local f_repo_url="https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list"
        local _f=`download_by_cache ${f_repo_url}`
        cat $_f | $_sudo tee ${f_repo} >/dev/null
    }
    if do_and_verify \
        "test -f $f_repo" \
        '_install' \
        'true'; then true \
     && cat $f_repo | log_lines debug \
     && true; \
    else true \
     && log_error "Fail to install nvidia-docker apt source" \
     && false; \
    fi && \
    true
}

DEFAULT_PRE_USER_LIST="root fuzhiwen"
# PRE_USER_<user_name>=<uid>:<grp>:<gid>:<group1{,group2...}:<passwd>
DEFAULT_PRE_USER_fuzhiwen=320437::537693:sudo:
DEFAULT_SSH_KEY_fuzhiwen=$(cat <<EOF | grep -v "^#" | xargs
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrMpLIRC338AkTChoskYLPjjN/LikxSdutXrgsNnFc8Wm9VoEuAwv4FQE6Rr/uQUIsJPjgFgRveYQDUbRfZpSsKRgz1MrP/eYOSX05oJP0fOX9HNqZzPbQAK2tu8DzCOEpAhqOThRMPnKxWH3JXSNf//MrlGaq6GWr8s/gUJV8r2J3ttCosmexUnIWOx4lWmdBwPBVixWqd+otWnoQi/YqSv2JLlbz/V6PzWhsDedLYPF4iZq49Dp5g+JcWLi98RiwJ4F3PbaUVWEOWrfy73IHmSBLnliH5n+Un8XxJpMpAnRnxhF14gqGs/ZeaBJVH8xNkaIWvgnukNTT6sVAvrLB fuzhiwen@bladesk1/id_rsa
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvcVlMAXzu6rDUCpE/phVIen6Mdtq8REMckESkdc1OeHR2bhTWTmEjj6LPy44ogs6E5jhOQG74rYgsPg3kZQAB7lxrhlKyVKYXuYFcqJQJfENWg4gJNROj6RY0OIUmK2PcxDTGaSfiO1UGYoWLNEma9JxixVYVbF6321qxH35/v1E8O3EInTUdX6iE3w+ZbvZ4UMwQztA5GwZnEo6CvvXlOPDAShrv+QA/Vs/kfWWDU/vATDSETjK8jLCKgZyG/gpkPrZJLHRHarpdHsefYOpy4qP4Ib9vRfbESsMhYnbshTLatDZnM+Wt+Kb4/pZEomI+XJH1gU7ptd18ECAKwyfx fuzhiwen@aliceworld2/id_rsa
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDjS1i8oM5l23ebp4RmYeo19GjfZbCIhCxRobf1e2gyCXskZ3gVDhKMGVh3lqXCFpU5JKuB7yqhaEj0PzJg/zquIgkWrw0DbKv+iPeGa/BdLVFwv3uCwmTfCD21hjJ5BAyQTT2Suvf9q6lZdu/4oN5n18uwPSpgp8r66Pdq14lLEz2CqtalKsRIUwr0AdcgIC7Al2qjdkb2V2rfpY6aH7vNkSz5p45s2IDVHhbd4paRVkxl6E54UEV8GeUs8i3WbSs5cnVqkM1e+7kdeTJBs53+QK+0qCiAfhtYT1yFFStEJflFqAjnOq4VufLfNDJHm13tA85ijGsZ3lOcKwaauE8XGCkQ/6FtXz/R6gPq/Ag52S2AuN2ojP3dEHTUk3PCddAeJLcutQwP9+Fb0AGXweH/lLJiKTvTcO4be9A8ScnhYmLYsWNIeri/uU8B7dVn+NliYwWKcN0nK3Q8seqg95L6NjncxXcmhIAz6SZzY+EY1wfmiA6zSHRVoGywlWSOZc7y+Q1Q31oppVdr9+si3nwpEC21beaYl0M4MdCHF8Ex/XskrT94oGjMpl9XQKmEPPwwMxj2yrcZ+/9n7Qx2ank4R617trjPue8+vQJixUJ2rSEZOOe+VNqwFseXG6hSX15QnOzv2kegd4x/1h+LOhJUmPP/JPJm4NxWuN9TvLyzBw== fuzhiwen@blahome/id_rsa
EOF
)
DEFAULT_PRE_USER_root=::::
DEFAULT_SSH_KEY_root=fuzhiwen
function setup_user() {
    true \
 && local _dry_run_prefix="" \
 && if [ "x${1}" == "x--dry-run" ]; then _dry_run_prefix="echo"; shift; fi \
 && local _USR=${1} \
 && if [ -n "${_USR}" ]; then shift; else echo "[W]: Setup ghost user? Abort!" >&2; return 1; fi \
 && true 'PRE_USER_<USR>=<UID>:<GRP>:<GID>:<group1{,group2...}:<PWD>' \
 && local _line="$@" \
 \
 && local _GID \
 && local _GID_E \
 && local _GPS \
 && local _GRP \
 && local _GRP_E \
 && local _PRE_USER_PASSWD \
 && local _PWD \
 && local _SSH_KEYS \
 && local _UID \
 && local _d_tmp \
 && local _ref_user \
 && local _sudo=$sudo \
 && if [ "$as_root" != "true" ]; then _sudo=""; fi \
 \
 && log_info "" \
 && log_info "Setup user \"${_USR}\"" \
 && log_info "" \
 \
 && _UID=`echo ${_line} | cut -d: -f1 -s` \
 && _GRP=`echo ${_line} | cut -d: -f2 -s` \
 && _GID=`echo ${_line} | cut -d: -f3 -s` \
 && _GPS=`echo ${_line} | cut -d: -f4 -s` \
 && _PWD=`echo ${_line} | cut -d: -f5 -s` \
 \
 && if $is_rhel; then true \
     && true "translate \"sudo\" as \"wheel\" in rh" \
     && _GPS=`echo "${_GPS}" | sed -e 's/sudo/wheel/g'` \
     && true; \
    elif $is_ubuntu; then true \
     && true "translate \"wheel\" as \"sudo\" in ub" \
     && _GPS=`echo "${_GPS}" | sed -e 's/wheel/sudo/g'` \
     && true; \
    fi \
 && if echo "${_GPS}" | tr ',' '\n' | grep -sqFx "docker" && ! getent group docker >/dev/null 2>&1; then true \
     && true "Auto ignore \"docker\" group if it has not been installed yet" \
     && _GPS=`echo "${_GPS}" | tr ',' '\n' | grep -vFx "docker" | xargs | tr ' ' ','` \
     && true; \
    fi \
 \
 && _PRE_USER_PASSWD=`eval "echo \\$PRE_USER_PASSWD_${_USR}" 2>/dev/null` \
 && _PWD=${_PRE_USER_PASSWD:-${_PWD}} \
 && if [ -n "${_PWD}" -a "x`type -t decode_unix_passwd`" == "xfunction" ]; then true \
     && _PWD=`decode_unix_passwd ${_PWD}` \
     && true; \
    fi \
 \
 && if [ -z "${_GRP}" ]; then true \
     && if _GRP_E="`id -n -g ${_USR} 2>/dev/null`"; then true \
         && _GRP=$_GRP_E \
         && true; \
        else true \
         && _GRP=$_USR \
         && true; \
        fi \
     && true; \
    fi \
 \
 && if [ -n "$_GID" ]; then true \
     && if _GID_E="`getent group $_GRP 2>/dev/null`"; then true \
         && _GID_E="`echo \"$_GID_E\" | cut -d: -f3`" \
         && if [ "$_GID" != "$_GID_E" ]; then true \
             && log_error "Error: unix group \"${_GRP:-${_USR}}\" was already exist but has different id \"$_GID_E\" than requested \"$_GID\"" \
             && false; \
            fi \
         && true; \
        fi \
     && true; \
   fi \
 \
 && if [ -z "`getent group ${_GRP:-$_USR} 2>/dev/null`" ]; then true \
     && log_info "" \
     && log_info "Create unix group \"${_GRP}\"" \
     && log_info "" \
     && eval ${_dry_run_prefix} $_sudo groupadd ${_GID:+"-g ${_GID}"} ${_GRP} \
     && log_info ">> `getent group ${_GRP}`" \
     && true; \
    fi \
 && if [ -z "`getent passwd ${_USR} 2>/dev/null`" ]; then true \
     && log_info "" \
     && log_info "Create unix user \"${_USR}\"" \
     && log_info "" \
     && eval ${_dry_run_prefix} $_sudo useradd \
            ${_UID:+"-u ${_UID}"} \
            ${_GRP:+"-g ${_GRP}"} \
            ${_GPS:+"-G ${_GPS}"} \
            -s /bin/bash -m \
            ${_USR} \
     && log_info ">> `getent passwd ${_USR}`" \
     && true; \
    fi \
 && if [ -n "${_PWD}" ]; then true \
     && log_info "" \
     && log_info "Change password of unix user \"${_USR}\"" \
     && log_info "" \
     && echo "${_USR}:${_PWD}" | if [ -n "${_dry_run_prefix}" ]; then cat -; else $_sudo chpasswd; fi \
     && true; \
    fi \
 && _SSH_KEYS=`eval "echo \\$SSH_KEY_${_USR}" 2>/dev/null` \
 && if [ -n "$_SSH_KEYS" ]; then true \
     && if [ "`echo \"$_SSH_KEYS\" | wc -w`" = "1" ]; then true \
         && _ref_user=$_SSH_KEYS \
         && log_info "Reference ssh keys of user \"$_USR\" from \"$_ref_user\"" \
         && if _SSH_KEYS="`eval ${_sudo:+${_sudo} -u ${_ref_user}} cat ~${_ref_user}/.ssh/authorized_keys 2>/dev/null`"; then true \
             && _SSH_KEYS=`echo "$_SSH_KEYS" | xargs` \
             && true; \
            else true \
             && _SSH_KEYS=`eval "echo \\$SSH_KEY_${_ref_user}" 2>/dev/null` \
             && true; \
            fi \
         && true; \
        fi \
     && log_info "" \
     && log_info "Setup ssh keys of unix user \"${_USR}\"" \
     && log_info "" \
     && eval ${_dry_run_prefix} ${_sudo:+${_sudo} -u ${_USR}} mkdir -p ~${_USR}/.ssh \
     && _d_tmp=`mktemp -d /tmp/XXXXXXXX` \
     && { eval ${_sudo:+${_sudo} -u ${_USR}} sort -u ~${_USR}/.ssh/authorized_keys 2>/dev/null | cat - >$_d_tmp/old 2>/dev/null || true; } 2>/dev/null \
     && { cat $_d_tmp/old; echo "${_SSH_KEYS}"; } | \
        sed -e 's/^"//g' -e 's/"$//g' -e 's/  *ssh-/\nssh-/g' | sort -u >$_d_tmp/new \
     && if ! _diff=`diff -u $_d_tmp/old $_d_tmp/new`; then true \
         && echo "$_diff" | sed -e "s/^/>> [${_USR}'s ssh_key diff]: /g" | log_lines debug \
         && cat $_d_tmp/new | if [ -n "${_dry_run_prefix}" ]; then cat -; else eval ${_sudo:+${_sudo} -u ${_USR}} tee ~${_USR}/.ssh/authorized_keys >/dev/null; fi \
         && true; \
        fi \
     && eval ${_dry_run_prefix} ${_sudo:+${_sudo} -u ${_USR}} chmod -R go-rwx ~${_USR}/.ssh \
     && eval ${_dry_run_prefix} ${_sudo:+${_sudo} -u ${_USR}} chown -R ${_USR} ~${_USR}/.ssh \
     && if [ -d "$_d_tmp" ]; then true \
         && rm -f $_d_tmp/* \
         && rmdir $_d_tmp \
         && true; \
        fi \
     && true; \
    fi \
 && true; \
}
function setup_users() {
    true \
 && log_info "" \
 && log_info "Setup users \"${PRE_USER_LIST}\"" \
 && log_info "" \
 && local err_cnt=0 \
 && for _USR in ${PRE_USER_LIST}; \
    do true \
     && _line=`eval "echo \\$PRE_USER_${_USR}" 2>/dev/null` \
     && if ! setup_user ${_USR} "${_line}"; then ((err_cnt+=1)); break; fi \
    done \
 && test ${err_cnt} -eq 0 \
 && true;
}
function install_slurm_rh() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    local _slurm_build_url_prefix="https://bitbucket.org/dillonfzw/erots/raw/8346748b1875ab0cdd22f7e25cbca8cc69434b61/slurm/RPMS_ssl_auth_none/x86_64/"
    local _slurm_build_ver=${slurm_build_ver:-"17.11.9-1.el7.x86_64"}
    local -a _pkgs=(
        "slurm"
        "slurm-contribs"
        "slurm-devel"
        "slurm-example-configs"
        "slurm-libpmi"
        "slurm-openlava"
        "slurm-pam_slurm"
        "slurm-perlapi"
        "slurm-slurmctld"
        "slurm-slurmd"
        "slurm-slurmdbd"
        "slurm-torque"
    )
    function _join_url() {
        echo "${_slurm_build_url_prefix}${1}-${_slurm_build_ver}.rpm"
    }
    function _install_slurm() {
        local -a _rpm_urls=(`for_each_op --silent _join_url ${_pkgs[@]}`)
        local -a _rpm_files=(`for_each_op --silent download_by_cache ${_rpm_urls[@]}`)
        #$_sudo yum install -y ${_rpm_files[@]}
        pkg_install_yum ${_rpm_files[@]}
    }
    if do_and_verify \
        'eval pkg_list_installed ${_pkgs[@]}' \
        '_install_slurm' \
        "true"; then
        pkg_list_installed ${_pkgs[@]} | log_lines debug
    else
        log_error "Fail to install \"slurm\""
        false
    fi
}
function install_slurm_ubuntu() {
    local -a _pkgs=(
        "deb:slurm-wlm"
        "deb:munge"
    ) && \
    if do_and_verify \
        'eval pkg_verify ${_pkgs[@]}' \
        'eval pkg_install ${_pkgs[@]}' \
        "true"; then
        pkg_list_installed ${_pkgs[@]} | log_lines debug
    else
        log_error "Fail to install \"slurm\""
        false
    fi
}
function install_slurm() {
    print_title "Check and install \"Slurm\" ..." && \
    if $is_rhel; then
        install_slurm_rh $@
    elif $is_ubuntu; then
        install_slurm_ubuntu $@
    else
        false
    fi
}
function install_openresty_centos() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    # https://openresty.org/cn/linux-packages.html
    $_sudo yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo && \
    local -a _pkgs=(
        "openresty"
            "rpm:openresty-doc"
        "openresty-opm"
        "openresty-resty"
    ) && \
    if do_and_verify \
        'eval pkg_verify ${_pkgs[@]}' \
        'eval pkg_install ${_pkgs[@]}' \
        "true"; then
        pkg_list_installed ${_pkgs[@]} | log_lines debug
    else
        log_error "Fail to install \"openresty\""
        false
    fi && \
    true
}
function install_openresty_ubuntu() {
    # https://openresty.org/cn/linux-packages.html
    # 导入我们的 GPG 密钥：
    if do_and_verify \
        'eval apt-key fingerprint 97DB7443D5EDEB74 | grep -sqi "97DB 7443 D5ED EB74"' \
        'eval curl ${CURL_PROXY:+--proxy} ${CURL_PROXY} -fsSL https://openresty.org/package/pubkey.gpg | $sudo apt-key add -' \
        'true'; then
        # pub   rsa2048 2017-05-21 [SC]
        #      E522 18E7 0878 97DC 6DEA  6D6D 97DB 7443 D5ED EB74
        #      uid           [ unknown] OpenResty Admin <admin@openresty.com>
        #      sub   rsa2048 2017-05-21 [E]
        apt-key fingerprint 97DB7443D5EDEB74 | log_lines debug
    else
        log_error "Fail to setup openresty apt key"
        false
    fi && \
    local codename=`grep "^UBUNTU_CODENAME=" /etc/os-release | cut -d= -f2-` && \
    echo "deb https://openresty.org/package/ubuntu $codename main" \
        | $sudo tee /etc/apt/sources.list.d/openresty.list && \
    $sudo apt-get update && \
    local -a _pkgs=(
        "openresty"
        "openresty-opm"
        "openresty-resty"
            "deb:openresty-restydoc"
    ) && \
    if do_and_verify \
        'eval pkg_verify ${_pkgs[@]}' \
        'eval pkg_install ${_pkgs[@]}' \
        "true"; then
        pkg_list_installed ${_pkgs[@]} | log_lines debug
    else
        log_error "Fail to install \"openresty\""
        false
    fi && \
    true
}
function install_openresty() {
    print_title "Check and install \"OpenResty\" ..." && \
    if $is_rhel; then
        install_openresty_centos $@
    elif $is_ubuntu; then
        install_openresty_ubuntu $@
    else
        false
    fi
}
function install_rabbitmq_ubuntu() {
    # 熔断，进错门了
    if ! $is_ubuntu; then return 1; fi
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    # 预置的apt的key，防止下不下来
    local signing_key='-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBFc6394BEACzae+l1pU31AMhJrRx4BqYv8ZCVUBOeiS3xIcgme1Oq2HSq/Vt
x49VPU9xY9ni4GjOU9c9/J9/esuigbctCN7CdR8bqN/srwqmuIPNIS/MvGhNimjO
/EUKcZtmJ5fnFk08bzjkyS/ScEzf3jdJadrercoPpbAKWnzCUblX8AdFDyDJhl65
TlSKS9+Sz0tfSdUIa0LpyJHZmLQ4chCy6KbDUAvchM2xUTIEJwx+sL4n/J6yYkZl
L90mVi4QEYl1Cajioeg9zxduoUmXq0SR5gQe6VIaXYrIk2gOEMNQL4P/4CKEn9No
1yvUP1+dSYTyvbmF+1pr16xPyNpw3ydmxDX9VxZAEnzPabB8Uortirtt0Dpopufy
TJR99dPcKV+BWJtQF6xD30kj8LaDfhyVeB6Bo+L0hhhvnZYWkps8ZJ1swcoBjir7
RDq8hJVqu8YHrzsiFL5Ut/pRkNhrK83GVOxnTndmj/MNboExD3IR/yjCiWNxC9Zu
Iaedv2ux+0KrQVTDU7I97x2GDwyiUMnKL7IKWSOTDR4osv5RlJzAovuv2+lZ8sle
ZvCEWOGeEYYM1VLDgXhPQdMwyizJ113oobxbqF+InlWq/T9mWmJDLb4wAiha3KKE
XJi8wXkJMdRQ0ftM1zKD8qBMukyVndZ6yNQrx3uHAP/Yl2XKPUbtkq/KVQARAQAB
tDBSYWJiaXRNUSBSZWxlYXNlIFNpZ25pbmcgS2V5IDxpbmZvQHJhYmJpdG1xLmNv
bT6JAjcEEwEKACEFAlc6394CGwMFCwkIBwMFFQoJCAsFFgIDAQACHgECF4AACgkQ
a3OjbmAm38qiJQ/+PkS0I+Be1jQINT2F4f8Mwq4Zxcqm4whbg6DH6zkvvqSqXFNB
wg7HVsC3qQ9Uh6OPw3dziBHmsOE50DpeqCGjHGacJ/Az/00PHKUn8eJQ/dIB1rla
PcSOBUP2CrMLLh9PbP1ZDm2/6gpInyYIRQox8k7j5PnHSVprYAA6tp/11i351WOQ
WkuN54482svVRfUEttt0NPLXtXJQl4V1eBt8+J11ZSh0mq2QSTxg211YBY0ugeVx
Q0PBIWvrNmcsnBttj5MJ/4L9nFmuemiSS3M9ONjwDBxaiaWCwxFwKXGensNOWeZy
bBfbhQxTpOKSNgyk+MymrG5EyI7fVlbmmHEhuYmV4pJadXmW1a9wvRHap/aLR1Aw
akFI29CABbnYD3ZXg+DmNqqE6um5Uem2zYr/9hfSL5KuuwawoyW8HV4gKBe+MgW1
n1lECvECt9Bn2VepjIUCv4gfHBDel5v1CXxZpTnHLt8Hsno1qTf6dGvvBYEPyTA+
cAlUeCmfjhBVNQEapUzgW0D7E8JaWHAbJPtwwp/iIO/xqEps3VGOouG+G4GPiABh
CP7hYUceecgVAF5g75gcI2mZeXAfbHVdfffZZXSYA7RjOAA1bLOopjq6UvYyIBhe
D72feGzkEPtjTpHtqttDFO9ypBEwnJjTpw2uTcBIbc6E7AThaZeEF/JC84aIRgQQ
EQoABgUCV0RROwAKCRD3uM6mBW6OVjBwAJ9j4tcWbw03rBy5j4LjP9a4EToJcwCf
TEfCiAWldVzFkDM9jBfu0V+rIwC5Ag0EVzrf3gEQAN4Nor5B6nG+Rrb0yzI7Q1sO
VM+OD6CdCN4Ic9E3u+pgsfbtRQKRuSNk8LyPVOpI5rpsJhqGKEDOUWEtb7uyfZxV
J57QhbhIiJTJsFp50mofC58Kb8+vQ4x6QKdW9dwNSH3+BzwHi6QN+b+ZFifC4J6H
q/1Ebu1b6q7aWjY7dPh2K+XgKTIq6qio9HFqUTGdj2QM0eLiQ6FDDKH0cMvVqPGD
dwJXAYoG5Br6WeYFyoBiygfaKXMVu72dL9YhyeUfGJtrZkRv6zqrkwnjWL7Xu1Rd
5gdYXV1QBz3SyBdZYS3MCbvkMLEkBCXrMG4zvReasrkanMANRQyM/XPMS5joO5dD
cvL5FDQeOy7+YlznkM5pAar2SLrJDerjVLBvXdCBX4MjsW05t3OPg6ryMId1rHbY
XtPslrCm9abox53dUtd16Gp/FSxs2TT3Wbos0/zel/zOIyj4kcVR3QjplMchlWOA
YLYO5VwM1f49/xvFOEMiyb98ameS0fFf1pNAstLodEDxgXIdzoelxbybYrRLymgD
tp3gkf53mhSN1q5Qu+/CQbSChqbcAsT8qUSdeGkvzR4qKEzDh+dEo4lheNwi7xPZ
/kj2RjaKs6jjxUWw9oyqxdGt9IwbRo+0TV+gLKUv/uj/lVKO5O3alNN37lobLQbF
5fFTrp9oXz2eerqAJFI7ABEBAAGJAh8EGAEKAAkFAlc6394CGwwACgkQa3OjbmAm
38pltg//W37vxUm6OMmXaKuLtE/G4GsM7QHD/OIvXZw+HIzyVClsM8v0+DGolOGU
Qif9HBRZfrgEWHTVeTDkynq3y7hbA2ekXEGvdKMVTt1JqRWgWPP57dAu8aVaJuR6
b4HLS0dfavXxnG1K2zunq3eARoOpynUJRzdG95JjXaLyYd1FGU6WBfyaVEnaZump
o6evG8VcH8fj/h88vhc3qlU+FdP0B8pb6QQpkqZGJeeiKP/yVFI/wQEqITIs1/ST
stzNGzIeUnNITjUCm/O2Hy+VmrYeFqFNY0SSdRriENnbcxOZN4raQfhBToe5wdgo
vUXCJaaVTd5WMGJX6Gn3GevMaLjO8YlRfcqnD7rAFUGwTKdGRjgc2NbD0L3fB2Mo
Y6SIAhEFbVWp/IExGhF+RTX0GldX/NgYMGvf6onlCRbY6By24I+OJhluD6lFaogG
vyar4hPA2PMw2LUjR5sZGHPGd65LtXviRn6E1nAJ8CM9g9s6LD5nA9A7m+FEI0rL
LVJf9GjgRbyD6QF53AZanwGUoKUPaF+Jp6HhVXNWEyc2xV1GQL+9U2/BX6zyzAZP
fVeMPOtWIF9ZPqp7nQw9hhzfYWxJRh4UZ90/ErwzKYzZLYZJcPNMSbScPVB/th/n
FfI07vQHGzzlrJi+064X5V6BdvKB25qBq67GbYw88+XcrM6R+Uk=
=tsX2
-----END PGP PUBLIC KEY BLOCK-----'
    local -a _pkgs=(
        "deb:apt-transport-https"
    )
    if ! do_and_verify \
        'eval pkg_verify ${_pkgs[@]}' \
        'eval pkg_install ${_pkgs[@]}' \
        "true"; then
        false
    fi && \

    # 安装apt的key
    if do_and_verify \
        'eval apt-key fingerprint 6026DFCA | grep -sqi "6026 DFCA"' \
        'eval curl ${CURL_PROXY:+--proxy} ${CURL_PROXY} -fsSL https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc | $_sudo apt-key add -' \
        #'eval $_sudo apt-key adv --keyserver "hkps://keys.openpgp.org" --recv-keys "0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"' \
        #'eval echo $signing_key | $_sudo apt-key add -' \
        'true'; then
        apt-key fingerprint 6026DFCA | log_lines info
    else
        log_error "Fail to import rabbitmq-release signing key"
        false
    fi && \

    # 安装apt的source
    local f_repo=/etc/apt/sources.list.d/bintray.erlang.list && \
    local distribution="" && \
    if grep -sq "VERSION_ID=\"16.04\"" /etc/os-release; then
        distribution="xenial"
    elif grep -sq "VERSION_ID=\"18.04\"" /etc/os-release; then
        distribution="bionic"
    else
        log_error "Unsupported ubuntu version"
        false
    fi && \
    { cat <<EOF
# This repository provides Erlang packages produced by the RabbitMQ team
# See below for supported distribution and component values
## Installs the latest Erlang 23.x release.
## Change component to "erlang-22.x" to install the latest 22.x version.
## "bionic" as distribution name should work for any later Ubuntu or Debian release.
## See the release to distribution mapping table in RabbitMQ doc guides to learn more.
deb https://dl.bintray.com/rabbitmq-erlang/debian $distribution erlang
## Installs latest RabbitMQ release
deb https://dl.bintray.com/rabbitmq/debian $distribution main
EOF
    } | $_sudo tee $f_repo && \
    # 更新repo
    { $_sudo apt-get update || true; } && \
    local -a _pkgs=(
        "deb:rabbitmq-server"
    ) && \
    if do_and_verify \
        'eval pkg_verify ${_pkgs[@]}' \
        'eval pkg_install ${_pkgs[@]}' \
        "true"; then
        pkg_list_installed ${_pkgs[@]}
    else
        log_error "Fail to install rabbitmq-server"
        false
    fi && \
    true
}
function install_rabbitmq_rh() {
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi

    local releasever=7
    local f_repo=/etc/yum.repos.d/Bintray-rabbitmq.repo
    if [ ! -f $f_repo ]; then
        { cat >$f_repo <<EOF
[bintray-rabbitmq-server]
name=bintray-rabbitmq-rpm
baseurl=https://dl.bintray.com/rabbitmq/rpm/rabbitmq-server/v3.8.x/el/$releasever/
gpgcheck=0
repo_gpgcheck=0
enabled=1
EOF
        } | $_sudo tee $f_repo
    fi && \
    $_sudo rpm --import https://www.rabbitmq.com/rabbitmq-release-signing-key.asc && \
    #$_sudo rpm --import https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc && \
    local -a _pkgs=(
        "rpm:rabbitmq-server"
    ) && \
    if do_and_verify \
        'eval pkg_verify ${_pkgs[@]}' \
        'eval pkg_install ${_pkgs[@]}' \
        "true"; then
        pkg_list_installed ${_pkgs[@]}
    else
        log_error "Fail to install rabbitmq-server"
        false
    fi && \
    true
}
function install_rabbitmq() {
    print_title "Check and install \"RabbitMQ\" ..." && \
    if $is_rhel; then
        install_rabbitmq_rh $@
    elif $is_ubuntu; then
        install_rabbitmq_ubuntu $@
    else
        false
    fi
}
function install_iluvatar_sdk_cmake() {
    local _release=${1:-latest}
    if [ -n "${1}" ]; then shift; fi
    local _install_dir=${1:-/opt}
    if [ -n "${1}" ]; then shift; fi
    local _sudo=${sudo:-sudo}
    if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi
    local -a _rel_pkgs=`scrape_iluvatar_sdk_pkgs $_release`
    function _filter_op() { echo "$@" | grep -si "cmake.*sh"; }
    local -a _pkgs=`array_filter _rel_pkgs[@] _filter_op`
    if [ ${#_pkgs[@]} -ne 1 ]; then
        log_error "No unique cmake pkg was scrapped for release \"${_release}\": `declare_p_val _pkgs`"
        return 1
    fi
    local _pkg_f=`download_by_cache ${_pkgs[0]}`
    if [ "x$download_only" == "xtrue" ]; then return 0; fi
    local _info=`bash ${_pkg_f} --version`
    if echo "${_info}" | grep -sqF "3.21.5-corex.2.3.0" >/dev/null 2>&1; then true \
     && ${_sudo} bash ${_pkg_f} \
          --prefix=${_install_dir} \
          --include-subdir \
          --skip-license \
     && true; \
    else true \
     && log_warn "Unknown version of corex-cmake, use default install flags: ${_info}" \
     && ${_sudo} bash ${_pkg_f} \
          --prefix=${_install_dir} \
          --include-subdir \
          --skip-license \
     && true; \
    fi
}
function uninstall_iluvatar_sdk_corex() {
    local _sudo=${sudo:-sudo}
    if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi

    true \
 && set -x \
 && local err_cnt=0 \
 && local _uninstaller \
 && for _uninstaller in `find /usr/local/corex*/ -name "corex-uninstaller" -type f 2>/dev/null | xargs`; do true \
     && if [ ! -f ${_uninstaller} ]; then continue; fi \
     && if ! ${_sudo} ${_sudo:+-n} ${_uninstaller}; then ((err_cnt+=1)); break; fi \
     && local _dir=`echo ${_uninstaller} | cut -d\/ -f-4` \
     && if ! echo "${_dir}" | grep -sq "^/usr/local/corex"; then ((err_cnt+=1)); break; fi \
     && if [ ! -d ${_dir}/ ]; then continue; fi \
     && if ! ${_sudo} ${_sudo:+-n} find ${_dir}/ -delete; then ((err_cnt+=1)); break; fi \
     && if [ -d ${_dir}/ ]; then ((err_cnt+=1)); break; fi \
     && true; \
    done \
 && test ${err_cnt} -eq 0 \
 && local _kmd \
 && for _kmd in itr_peer_mem_drv bi_driver iluvatar; do true \
     && _kmd=`lsmod | grep -E "^${_kmd} " | awk '{print $1}'` \
     && if ! if [ -n "${_kmd}" ]; then ${_sudo} ${_sudo:+-n} modprobe -r ${_kmd}; fi; then ((err_cnt+=1)); break; fi \
     && true; \
    done \
 && test ${err_cnt} -eq 0 \
 && for _kmd in `find /lib/modules -name "bi_driver.*" -o -name "iluvatar.*" | xargs`; do true \
     && if ! ${_sudo} ${_sudo:+-n} rm -f ${_kmd}; then ((err_cnt+=1)); break; fi \
     && true; \
    done \
 && test ${err_cnt} -eq 0 \
 && true; \
}
function install_iluvatar_sdk_corex() {
    local _release=${1:-latest}
    if [ "x${_release}" = "x${1}" ]; then shift; fi
    # drop unused arguments
    while echo "$@" | grep -sq "^[-]-\? ";
    do
        shift
    done

    local _sudo=${sudo:-sudo}
    if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi

    local _pkg_f=${_release}
    if [ ! -f "${_release}" ]; then
        local -a _rel_pkgs=`scrape_iluvatar_sdk_pkgs $_release`
        function _filter_op() { echo "$@" | grep -si "corex-installer.*run"; }
        local -a _pkgs=`array_filter _rel_pkgs[@] _filter_op`
        if [ ${#_pkgs[@]} -ne 1 ]; then
            log_error "No unique corex pkg was scrapped for release \"${_release}\": `declare_p_val _pkgs`"
            return 1
        fi
        _pkg_f=`download_by_cache ${_pkgs[0]}`
        if [ "x$download_only" == "xtrue" ]; then return 0; fi
    fi
    local _info=`bash ${_pkg_f} --info`

    if echo "$_info" | grep -sqF "2.3.0-iluvatar" >/dev/null 2>&1; then true \
     && {
        # $ bash /home/fuzhiwen/.cache/download/26/47/corex-installer-linux64-2.3.0_x86_64_10.2.run --help
        # Corex Toolkit Installer.
        # Usage: [COMMAND] [OPTIONS] ...
        #
        # Options:
        #   --silent
        #     Performs an installation with no further user-input and minimal command-line output based on the options provided below. Silent installations are useful for scripting the installation of CUDA. Using this option implies acceptance of the EULA. The following flags can be used to customize the actions taken during installation. At least one of --driver and --toolkit must be passed if running with non-root permissions.
        #
        #   --driver
        #     Install the Corex Driver.
        #
        #   --toolkit
        #     Install the Corex Toolkit.
        #
        #   --toolkit-path=<PATH>
        #     Install the Corex Toolkit to the <path> directory. If this flag is not provided, the default path of <default_toolkitpath> is used.
        #
        #   --kernel-source-path=<PATH>
        #     Tells the driver installation to use <path> as the kernel source directory when building the Corex kernel module. Required for systems where the kernel source is installed to a non-standard location.
        #
        #   --cuda-path=<PATH>
        #     Tells the toolkit installation to use <cuda-path> as the cuda source directory.
        #
        #   --no-symlink
        #     Prevents the /usr/local/corex symbolic link from being created.
        #
        # Extras:
        #   --tmpdir=<path>
        #     Performs any temporary actions within <path> instead of /tmp. Useful in cases where /tmp cannot be used (doesn't exist, is full, is mounted with 'noexec', etc.).
        #
        #   --help
        #     Prints this help message.
            true;
        } \
     && ${_sudo} bash ${_pkg_f} \
          --silent \
          --no-symlink \
          --toolkit \
          --cuda-path=${CUDA_PATH:-/usr/local/cuda-10.2} \
          $@ \
     && true; \
    else true \
     && log_warn "Unknown version of corex-installer, use default install flags: ${_info}" \
     && ${_sudo} bash ${_pkg_f} \
          --silent \
          --no-symlink \
          --toolkit \
          --cuda-path=${CUDA_PATH:-/usr/local/cuda-10.2} \
     && true; \
    fi
    true
}
function install_iluvatar_sdk_corex_samples() {
    local _release=${1:-latest}
    if [ -n "${1}" ]; then shift; fi
    local _install_dir=${1:-$HOME/workspace}
    if [ -n "${1}" ]; then shift; fi
    local _sudo=${sudo:-sudo}
    if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi
    local -a _rel_pkgs=`scrape_iluvatar_sdk_pkgs $_release`
    function _filter_op() { echo "$@" | grep -si "corex-samples"; }
    local -a _pkgs=`array_filter _rel_pkgs[@] _filter_op`
    if [ ${#_pkgs[@]} -ne 1 ]; then
        log_error "No unique corex-samples pkg was scrapped for release \"${_release}\": `declare_p_val _pkgs`"
        return 1
    fi
    local _pkg_f=`download_by_cache ${_pkgs[0]}`
    if [ "x$download_only" == "xtrue" ]; then return 0; fi
    local _info=`bash ${_pkg_f} --info`

    if echo "$_info" | grep -sqF "2.3.0-iluvatar" >/dev/null 2>&1; then true \
     && {
        # $ bash /home/fuzhiwen/.cache/download/26/28/co
        # rex-samples-2.3.0_x86_64.run --help
        # Corex Samples Installer.
        # Usage: [COMMAND] [OPTIONS] ...
        #
        # Options:
        #   -p,--prefix
        #     Specify installation path. (default: $HOME)
        #
        # Extras:
        #   --tmpdir=<path>
        #     Performs any temporary actions within <path> instead of /tmp. Useful in cases where /tmp cannot be used (doesn't exist, is full, is mounted with 'noexec', etc.).
        #
        #   --help
        #     Prints this help message.
            true;
        } \
     && if [ ! -d ${_install_dir} ]; then mkdir -p ${_install_dir}; fi \
     && ${_sudo} bash ${_pkg_f} \
          --prefix=${_install_dir} \
     && true; \
    else true \
     && log_warn "Unknown version of corex-samples, use default install flags: ${_info}" \
     && ${_sudo} bash ${_pkg_f} \
          --prefix=${_install_dir} \
     && true; \
    fi
    true
}
function install_iluvatar_sdk_corex_driver() {
    local _copy_only=false
    if [ "x${1}" == "x--copy-only" ]; then local _copy_only=true; shift; fi
    local _release=${1:-latest}
    if [ -n "${1}" ]; then shift; fi
    local _install_dir=${1:-/opt}
    if [ -n "${1}" ]; then shift; fi
    local _sudo=${sudo:-sudo}
    if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi
    local -a _rel_pkgs=`scrape_iluvatar_sdk_pkgs $_release`
    function _filter_op() { echo "$@" | grep -si "corex-driver"; }
    local -a _pkgs=`array_filter _rel_pkgs[@] _filter_op`
    if [ ${#_pkgs[@]} -ne 1 ]; then
        log_error "No unique corex-driver pkg was scrapped for release \"${_release}\": `declare_p_val _pkgs`"
        return 1
    fi
    local _pkg_f=`download_by_cache ${_pkgs[0]}`
    if [ "x$download_only" == "xtrue" ]; then return 0; fi
    local _info=`bash ${_pkg_f} --info`

    if [ "x${_copy_only}" == "xtrue" ]; then true \
     && ${_sudo} ${_sudo:+-n} cp -p ${_pkg_f} ${_install_dir}/`basename ${_pkg_f}` \
     && return 0; \
    fi || return 1
    if echo "$_info" | grep -sqF "2.3.0-iluvatar" >/dev/null 2>&1; then true \
     && {
        #
        # $ bash ~/.cache/download/56/49/corex-driver-linux64-4.1.0_x86_64_10.2.run --info
        # Identification: Corex Driver
        # Target directory: corex-driver
        # Uncompressed size: 18536 KB
        # Compression: gzip
        # Date of packaging: Mon Jun 24 10:15:52 CST 2024
        # Built with Makeself version 2.3.0-iluvatar on linux-gnu
        # Build command was: /home/corex/sw_home/local/bin/makeself \
        #     "--help-header" \
        #     "/home/corex/sw_home/integ/ixpkg/help/driver.txt" \
        #     "/home/corex/sw_home/local/package/corex-driver" \
        #     "/home/corex/sw_home/local/package/corex-driver-linux64-4.1.0_x86_64_10.2.run" \
        #     "Corex Driver" \
        #     "./corex-driver-installer"
        # Script run after extraction:
        #      ./corex-driver-installer
        # corex-driver will be removed after extraction
        #
        # $ bash ~/.cache/download/56/49/corex-driver-linux64-4.1.0_x86_64_10.2.run --help
        # Corex Driver Installer.
        # Usage: [COMMAND] [OPTIONS] ...
        #
        # Options:
        #   --kernel-source-path=<KERNEL_SOURCE_PATH>
        #     Set <KERNEL_SOURCE_PATH> as the driver installation to use <path> as the kernel source directory when building the Corex kernel module. Required for systems where the kernel source is installed to a non-standard location.
        #
        #   --disable-dkms
        #     DKMS infrastructure can automatically build a new kernel module when changing kernels. this option will bypass DKMS detect and disable use of it.
        #
        #   --module-signing-secret-key=<MODULE_SIGNING_SECRET_KEY>
        #     Specify a path to a private key to use for signing the kernel module. The corresponding public key must also be provided.
        #
        #   --module-signing-public-key=<MODULE_SIGNING_PUBLIC_KEY>
        #     Specify a path to a public key to use for verifying the signature of the kernel module. The corresponding private key must also be provided.
        #
        # Extras:
        #   --tmpdir=<path>
        #     Performs any temporary actions within <path> instead of /tmp. Useful in cases where /tmp cannot be used (doesn't exist, is full, is mounted with 'noexec', etc.).
        #
        #   --help
        #     Prints this help message.
            true;
        } \
     && if [ ! -d ${_install_dir} ]; then mkdir -p ${_install_dir}; fi \
     && ${_sudo} bash ${_pkg_f} \
     && true; \
    else true \
     && log_warn "Unknown version of corex-driver, use default install flags: ${_info}" \
     && ${_sudo} bash ${_pkg_f} \
     && true; \
    fi
    true
}
function install_iluvatar_sdk_apps() {
    if [ "x`type -t install_iluvatar_sdk_${1}_apps`" == "xfunction" ]; then
        local _site_prefix_8yU6=${1}
        if [ "${FUNCNAME[1]}" != "install_iluvatar_sdk_${_site_prefix_8yU6}_apps" ]; then
            shift
            install_iluvatar_sdk_${_site_prefix_8yU6}_apps $@
            return $?
        fi
    fi
    local _release=${1:-latest}
    if [ -n "${1}" ]; then shift; fi
    if [ "x${1}" == "x-" -o "x${1}" == "x--" ]; then shift; fi
    local _tf_ver=${_tf_ver:-2}
    local -a _rel_pkgs=`scrape_iluvatar_sdk_pkgs $_release`
    function _filter_op() {
        local _line
        local _succ=0
        if echo "$@" | grep -sq -v "[-]cp${G_python_ver_major}${G_python_ver_minor}.*\.whl"; then true \
         && false; \
        elif echo "$@" | grep -sq "tensorflow-${_tf_ver}"; then true \
         && true; \
        elif echo "$@" | grep -sq "tensorflow-"; then true \
         && false; \
        fi
    }
    local -a _pkgs=`array_filter _rel_pkgs[@] _filter_op`
    #declare -p _pkgs
    if [ ${#_pkgs[@]} -eq 0 ]; then
        log_error "No sufficient pypi pkgs were scrapped for release \"${_release}\": `declare_p_val _pkgs`"
        return 1
    fi
    local _c
    _c=$(array_map _pkgs[@] download_by_cache) || { log_error "Fail to download pkgs, Abort!"; return 1; }
    if [ "x$download_only" == "xtrue" ]; then return 0; fi
    local -a _pkgs=${_c}

    # opencv-python uses skbuild now
    pkg_install_pip scikit-build && \
    pkg_install_pip ${_pkgs[@]} $@
}
function install_iluvatar_sdk_BI150r410_apps() {
    true set -x \
 && local _pyvers=${_pyvers:-`python3 -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))"`} \
 && if [ "${_pyvers}" == "3.10" ]; then true \
     && install_iluvatar_sdk_apps BI150r410 -- SharedArray==3.2.1 \
     && true; \
    else true \
     && install_iluvatar_sdk_apps BI150r410 \
     && true; \
    fi \
 && true; \
}
function scrape_iluvatar_sdk_pkgs() {
    if [ "x`type -t scrape_iluvatar_sdk_${1}_pkgs`" == "xfunction" ]; then
        local _site_prefix_8yU6=${1}
        if [ "${FUNCNAME[1]}" != "scrape_iluvatar_sdk_${_site_prefix_8yU6}_pkgs" ]; then
            shift
            scrape_iluvatar_sdk_${_site_prefix_8yU6}_pkgs $@
            return $?
        fi
    fi
    if ! declare -p G_iluvatar_sdk_pkgs_cache >/dev/null 2>&1; then
        declare -gA G_iluvatar_sdk_pkgs_cache=()
    fi
    local -A DEFAULT_download_url_prefix_map=(
        ["latest"]="http://10.150.9.95/corex/release_packages/3.0.1/x86/"
        #
        # BI-V100
        #
        ["BIr311"]="http://10.113.3.1/corex/release_packages/frequent_version/x86/bi100/3.1.1/"
        ["BIr310"]="http://10.113.3.1/corex/release_packages/3.1.0-BI/x86/"
        ["BIr301"]="http://10.150.9.95/corex/release_packages/3.0.1/x86/"
        ["BIr300"]="http://10.150.9.95/corex/release_packages/3.0.0/x86/"
        ["BIr231"]="http://10.150.9.95/corex/release_packages/2.3.1/x86/"
        ["BIr230"]="http://10.150.9.95/corex/release_packages/2.3.0/x86/"
        ["BIr221"]="http://10.150.9.95/corex/release_packages/2.2.1/x86/"
        ["BIr220"]="http://10.150.9.95/corex/release_packages/2.2.0/x86/"
        ["BIr211"]="http://10.150.9.95/corex/release_packages/2.1.1/x86/"
        ["BIr210"]="http://10.150.9.95/corex/release_packages/2.1.0/x86/"
        ["BIDailyLatest"]="http://10.113.3.1/corex/daily_packages/x86/latest/"
        # 智源二期BF16
        ["BId202307131382"]="http://10.113.3.1/corex/daily_packages/x86/20230713/1382/"
        #
        # BI-V150
        #
        ["BI150r410"]="http://10.113.3.1/corex/release_packages/4.1.0-BI150/x86/"
        # http://10.113.3.6/download/corex/release_packages/4.1.0_BI150/latest/x86_64/sdk/corex-docker-installer-4.1.0-10.2-ubuntu20.04-py3.10-x86_64.run
        ["BI150r410d20240603"]="http://10.113.3.6/corex/release_packages/4.1.0-BI150/20240603/x86_64/"
        ["BI150r340"]="http://10.113.3.1/corex/release_packages/3.4.0-BI150/x86/"
        ["BI150r330"]="http://10.113.3.1/corex/release_packages/3.3.0-BI150/x86/"
        ["BI150DailyLatest"]="http://10.113.3.1/corex/daily_packages/x86/bi150/latest/"
        ["BI150d2023101334"]="http://10.113.3.1/corex/release_packages/x86/bi150/20231013/34/"
        ["BI150d2023112376"]="http://10.113.3.1/corex/release_packages/x86/bi150/20231123/76/"
        #
        # MR-V100/50
        #
        ["MRr401"]="http://10.113.3.1/corex/release_packages/4.0.1-MR/x86/"
        ["MRr400"]="http://10.113.3.1/corex/release_packages/4.0.0-MR/x86/"
        ["MRr321p1"]="http://10.113.3.1/corex/release_packages/frequent_version/x86/mr/3.2.1-patch1/"
        ["MRr320"]="http://10.113.3.1/corex/release_packages/3.2.0-MR/x86/"
        ["MRr311"]="http://10.113.3.1/corex/release_packages/3.1.1-MR/x86/"
        ["MRr310"]="http://10.150.9.95/corex/release_packages/3.1.0-MR/x86/"
        ["MRr300Beta2"]="http://10.150.9.95/corex/release_packages/MR_Beta2/x86/"
        ["MRr230Beta1"]="http://10.150.9.95/corex/release_packages/MR_Beta1/x86/"
        ["MRDailyLatest"]="http://10.113.3.1/corex/daily_packages/x86/mr/latest/"
        # 移动集采
        ["MRd20221105231"]="http://10.150.9.95/corex/release_packages/Customization/mr_beta/20221105/x86/231/"
    )
    local -A DEFAULT_pkg_patterns_map=(
        ["latest"]="\.sh\"|\.run\"|\.whl\""
        #
        # BI-V100
        #
        ["BIr311"]="\.sh\"|\.run\"|\.whl\""
        ["BIr310"]="\.sh\"|\.run\"|\.whl\""
        ["BIr301"]="\.sh\"|\.run\"|\.whl\""
        ["BIr300"]="\.sh\"|\.run\"|\.whl\""
        ["BIr231"]="\.sh\"|\.run\"|\.whl\""
        ["BIr230"]="\.sh\"|\.run\"|\.whl\""
        ["BIr221"]="\.sh\"|\.run\"|\.whl\""
        ["BIr220"]="\.sh\"|\.run\"|\.whl\""
        ["BIr211"]="\.sh\"|\.run\"|\.whl\""
        ["BIr210"]="\.sh\"|\.run\"|\.whl\""
        ["BIDailyLatest"]="\.sh\"|\.run\"|\.whl\""
        # 智源二期BF16
        ["BId202307131382"]="\.sh\"|\.run\"|\.whl\""
        #
        # BI-V150
        #
        ["BI150r410"]="\.sh\"|\.run\"|\.whl\""
        ["BI150r410d20240603"]="\.sh\"|\.run\"|\.whl\""
        ["BI150r340"]="\.sh\"|\.run\"|\.whl\""
        ["BI150r330"]="\.sh\"|\.run\"|\.whl\""
        ["BI150DailyLatest"]="\.sh\"|\.run\"|\.whl\""
        ["BI150d2023101334"]="\.sh\"|\.run\"|\.whl\""
        ["BI150d2023112376"]="\.sh\"|\.run\"|\.whl\""
        #
        # MR-V100/50
        #
        ["MRr401"]="\.sh\"|\.run\"|\.whl\""
        ["MRr400"]="\.sh\"|\.run\"|\.whl\""
        ["MRr321p1"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
        ["MRr320"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
        ["MRr311"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
        ["MRr310"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
        ["MRr300Beta2"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
        ["MRr230Beta1"]="^cmake-.*\.sh\"|^corex-installer.*_beta_1.*\.run\"|^corex-samples.*\.run\"|\.whl\""
        ["MRDailyLatest"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
        # 移动集采
        ["MRd20221105231"]="^cmake-.*\.sh\"|^corex-driver.*\.run\"|^corex-installer.*\.run\"|^corex-samples.*\.run\"|\.whl\"|mr_iva_stress_pipeline.*\.run"
    )
    function _filter_87tY() {
        local _prefix_87tY=$1
        cut -d\" -f1 | \
        sed -e 's,/\+,/,g' | \
        sed -e "s,^,${_prefix_87tY},g" | \
        xargs
    }
    local site_prefix="${1:-latest}"
    local pkg_patterns="${2:-true}"
    if echo "${site_prefix}" | grep -sqE "^BI[dr]|^BI150[dr]|^MR[dr]" && [ -z "${ILUVATAR_APPS_TAG}" ]; then true \
     && ILUVATAR_APPS_TAG="$(echo ${site_prefix} | sed -e 's/^\(.*[dr][0-9]\{8\}\)\([0-9]\+\)$/\1.\2/')" \
     && true; \
    fi
    if [ -n "${ILUVATAR_APPS_TAG}" ]; then true \
     && local _ILUVATAR_APPS_site_prefix="$(echo ${ILUVATAR_APPS_TAG} | sed -e 's/\.//g')" \
     && local _ILUVATAR_APPS_site_dir_suffix="$(echo ${ILUVATAR_APPS_TAG} | sed -e 's/^.*\([0-9]\{8\}\)/\1/' -e 's,\.,/,g')" \
     && true "category = MRd | MRr | BId | BIr | BI150d | BI150r, r == release, d = daily" \
     && local _ILUVATAR_APPS_site_catetory="${ILUVATAR_APPS_TAG:0:3}" \
     && if [ "x${DEFAULT_download_url_prefix_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xMRd" -o \
                "x${_ILUVATAR_APPS_site_catetory}" == "x" \
            \) ]; then true \
         && DEFAULT_download_url_prefix_map["${_ILUVATAR_APPS_site_prefix}"]="http://10.113.3.1/corex/daily_packages/x86/mr/${_ILUVATAR_APPS_site_dir_suffix}/" \
         && true; \
        elif [ "x${DEFAULT_download_url_prefix_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xMRr" \
            \) ]; then true \
         && DEFAULT_download_url_prefix_map["${_ILUVATAR_APPS_site_prefix}"]="http://10.150.9.95/corex/release_packages/x86/mr/${_ILUVATAR_APPS_site_dir_suffix}/" \
         && true; \
        elif [ "x${DEFAULT_download_url_prefix_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBId" \
            \) ]; then true \
         && DEFAULT_download_url_prefix_map["${_ILUVATAR_APPS_site_prefix}"]="http://10.150.9.95/corex/daily_release_packages/x86/${_ILUVATAR_APPS_site_dir_suffix}/" \
         && true; \
        elif [ "x${DEFAULT_download_url_prefix_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBIr" \
            \) ]; then true \
         && DEFAULT_download_url_prefix_map["${_ILUVATAR_APPS_site_prefix}"]="http://10.150.9.95/corex/release_packages/x86/${_ILUVATAR_APPS_site_dir_suffix}/" \
         && true; \
        elif [ "x${DEFAULT_download_url_prefix_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBI150d" \
            \) ]; then true \
         && DEFAULT_download_url_prefix_map["${_ILUVATAR_APPS_site_prefix}"]="http://10.113.3.1/corex/daily_release_packages/x86/bi150/${_ILUVATAR_APPS_site_dir_suffix}/" \
         && true; \
        elif [ "x${DEFAULT_download_url_prefix_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBI150r" \
            \) ]; then true \
         && DEFAULT_download_url_prefix_map["${_ILUVATAR_APPS_site_prefix}"]="http://10.113.3.1/corex/release_packages/x86/bi150/${_ILUVATAR_APPS_site_dir_suffix}/" \
         && true; \
        fi \
     && if [ "x${DEFAULT_pkg_patterns_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xMRd" -o \
                "x${_ILUVATAR_APPS_site_catetory}" == "xMRr" -o \
                "x${_ILUVATAR_APPS_site_catetory}" == "x" \
            \) ]; then true \
         && DEFAULT_pkg_patterns_map["${_ILUVATAR_APPS_site_prefix}"]=${DEFAULT_pkg_patterns_map["MRDailyLatest"]} \
         && true; \
        elif [ "x${DEFAULT_pkg_patterns_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBId" -o \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBIr" \
            \) ]; then true \
         && DEFAULT_pkg_patterns_map["${_ILUVATAR_APPS_site_prefix}"]=${DEFAULT_pkg_patterns_map["BIDailyLatest"]} \
         && true; \
        elif [ "x${DEFAULT_pkg_patterns_map[${_ILUVATAR_APPS_site_prefix}]}" == "x" -a \( \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBI150d" -o \
                "x${_ILUVATAR_APPS_site_catetory}" == "xBI150r" \
            \) ]; then true \
         && DEFAULT_pkg_patterns_map["${_ILUVATAR_APPS_site_prefix}"]=${DEFAULT_pkg_patterns_map["BI150DailyLatest"]} \
         && true; \
        fi \
     && true; \
    fi
    # try expanding the site_prefix
    local _val=${DEFAULT_download_url_prefix_map[${site_prefix}]}
    if [ -n "${_val}" ]; then true \
     && pkg_patterns="${DEFAULT_pkg_patterns_map[${site_prefix}]}" \
     && site_prefix="${_val}" \
     && true;
    fi
    # prepare output variable
    local -a _target_urls=()
    # try picking from cache first
    _val="${G_iluvatar_sdk_pkgs_cache[@{site_prefix}]}"
    if [ -n "${_val}" ]; then true \
     && _target_urls+=${_val} \
     && declare -p _target_urls \
     && return 0 \
     && true; \
    fi
    # prepare sub-trees to be scrapped
    local -a urls=(
        "${site_prefix}"
        "${site_prefix}/not_release/"
        "${site_prefix}/add-on/"
        "${site_prefix}/tools/"
        "${site_prefix}/sdk/"
        `true && for _pyver_87tY in 3.{6,7,8,9,10} latest-wheels-3.{6,7,8,9,10};
         do
            echo "${site_prefix}/${_pyver_87tY}/"
            echo "${site_prefix}/${_pyver_87tY}/paddle/"
            echo "${site_prefix}/${_pyver_87tY}/tensorflow/"
            echo "${site_prefix}/${_pyver_87tY}/mindspore/"
            echo "${site_prefix}/${_pyver_87tY}/flash-attn/"
            echo "${site_prefix}/${_pyver_87tY}/not_installed/"

            echo "${site_prefix}/apps/py${_pyver_87tY}/"
            echo "${site_prefix}/apps/py${_pyver_87tY}/paddle/"
            echo "${site_prefix}/apps/py${_pyver_87tY}/tensorflow/"
            echo "${site_prefix}/apps/py${_pyver_87tY}/mindspore/"
            echo "${site_prefix}/apps/py${_pyver_87tY}/flash-attn/"
            echo "${site_prefix}/apps/py${_pyver_87tY}/not_installed/"

            echo "${site_prefix}/add-on/py${_pyver_87tY}/"
         done`
    )
    # scrape pkgs
    local _url
    for _url in ${urls[@]}
    do true \
     && _url=`echo "${_url}" | sed -e 's,\([^:]\)/\+,\1/,g'` \
     && local _f_url=`download_by_cache ${_url}` \
     && _target_urls+=($(cat ${_f_url} | grep "a href=" | sed -e 's/a href="/\n/' | \
            grep -E "${pkg_patterns}" | \
            _filter_87tY ${_url}
        )) \
     && true declare -p _target_urls >&2 \
     && true break \
     && true; \
    done
    # cache and output scrape result
    _val=`declare_p_val _target_urls`
    G_iluvatar_sdk_pkgs_cache[${site_prefix}]="${_val}"
    echo "${_val}"
}
function scrape_iluvatar_sdk_MRr230_pkgs() { scrape_iluvatar_sdk_pkgs MRr230; }
function scrape_iluvatar_sdk_r230_pkgs() { scrape_iluvatar_sdk_pkgs r230; }
function scrape_iluvatar_sdk_r221_pkgs() { scrape_iluvatar_sdk_pkgs r221; }
function scrape_iluvatar_sdk_BI150r341_pkgs() {
    true set -x \
 && local -a _urls=`scrape_iluvatar_sdk_pkgs BI150r340` \
 && function _filter_op() { echo "$@" | not_ grep -siE "corex-docker-installer-|corex-driver-|corex-installer-"; } \
 && local -a _urls=`array_filter _urls[@] _filter_op` \
 && _urls+=(
        "http://10.113.3.1/corex/release_packages/3.4.1-BI150/x86/sdk/corex-driver-linux64-3.4.1_x86_64_10.2.run"
        "http://10.113.3.1/corex/release_packages/3.4.1-BI150/x86/sdk/corex-installer-linux64-3.4.1_x86_64_10.2.run"
        #"http://10.113.3.1/corex/release_packages/3.4.1-BI150/x86/sdk/corex-docker-installer-3.4.1-10.2-centos7.8.2003-py3.10-x86_64.run"
        "http://10.113.3.1/corex/release_packages/3.4.1-BI150/x86/not_release/docker_installer/corex-docker-installer-3.4.1-10.2-ubuntu20.04-py3.10-x86_64.run"
    ) \
 && true "cache and output scrape result" \
 && _val=`declare_p_val _urls` \
 && G_iluvatar_sdk_pkgs_cache["BI150r341"]="${_val}" \
 && echo "${_val}" \
 && for _item in ${_urls[@]}; do log_info "${_item}"; done \
 && true; \
}
function cache_iluvatar_sdk() {
    true set -x \
 && local _release=${1:-latest} \
 && if [ -n "${1}" ]; then shift; fi \
 && local _link=false \
 && if [ "x${1}" == "x--link" ]; then local _link=true; fi \
 && local -a _pkgs=`scrape_iluvatar_sdk_pkgs $_release` \
 && local _cache_home=${cache_home:-${default_cache_home:-~/.cache/download}} \
 && local -a _files=`array_map _pkgs[@] download_by_cache` \
 && local _file \
 && if ${_link}; then for _file in ${_files[@]}; do true \
     && if [ ! -d ${_cache_home}/${_release} ]; then mkdir -p ${_cache_home}/${_release}; fi \
     && local _rpath=`echo ${_file} | sed -e "s,^${_cache_home}/,,g"` \
     && local _tfile=${_cache_home}/${_release}/`basename ${_rpath}` \
     && if [ ! -L ${_tfile} ]; then ln -s ../${_rpath} ${_tfile}; fi \
     && true; \
    done; fi \
 && true; \
}
function install_iluvatar_sdk() {
    true set -x \
 && local _release=${1:-latest} \
 && local _tf_ver=${_tf_ver:-2} \
 && if [ `whoami` = 'root' ]; then true \
     && local DEFAULT_install_dir=/opt \
     && true; \
    else true \
     && local DEFAULT_install_dir=$HOME/workspace \
     && true; \
    fi \
 && local _install_dir=${_install_dir:-${DEFAULT_install_dir}} \
 && if ! do_and_verify \
        'eval ls -1d '"${_install_dir}"'/cmake*corex*' \
        "install_iluvatar_sdk_cmake $_release ${_install_dir}" \
        'true'; then true \
     && log_error "Fail to install iluvatar corex's CMake" \
     && false; \
    fi \
 && if ! do_and_verify \
        'eval ls -1d /usr/local/corex-*' \
        "install_iluvatar_sdk_corex $_release" \
        'true'; then true \
     && log_error "Fail to install iluvatar corex's SDK" \
     && false; \
    fi \
 && if ! do_and_verify \
        'eval ls -1d '"${_install_dir}"'/corex-samples-*' \
        "install_iluvatar_sdk_corex_samples $_release ${_install_dir}" \
        'true'; then true \
     && log_error "Fail to install iluvatar corex's samples" \
     && false; \
    fi \
 && if ! do_and_verify \
        'eval ls -1d /opt/corex-driver*.run' \
        "install_iluvatar_sdk_corex_driver --copy-only $_release" \
        'true'; then true \
     && log_error "Fail to copy iluvatar corex's driver" \
     && false; \
    fi \
 && local -a _pyvers_a=() \
 && local _pyvers=${_pyvers:-`python3 -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))"`} \
 && _pyvers_a+=("${_pyvers}") \
 && true "Python 3.8 is mandatory if available" \
 && if [ "${_pyvers}" != "3.8" -a -n "`command -v python3.8`" ]; then true \
     && _pyvers_a+=("3.8") \
     && true;
    fi \
 && true "Python 3.10 is mandatory if available" \
 && if [ -n "`command -v python3.10`" ]; then true \
     && _pyvers_a+=("3.10") \
     && true;
    fi \
 && local err_cnt=0 \
 && for _pyvers in ${_pyvers_a[@]}; \
    do true \
     && if [ ${err_cnt} -gt 0 ]; then break; fi \
     && { ((err_cnt+=1)) || true; } \
     && local _pyvers_s=`echo ${_pyvers} | sed -e 's/\.//g'` \
     && local _pyvepath=${_install_dir}/corex${_release}py${_pyvers_s}tf${_tf_ver} \
     && log_info "Create Iluvatar Corex apps' Python${_pyvers} virtualenv at ${_pyvepath}" \
     && if [ -f ${_pyvepath}/bin/activate ]; then ((err_cnt-=1)); continue; else mkdir -p `dirname ${_pyvepath}`; fi \
     && if ! do_and_verify \
            "test -f ${_pyvepath}/bin/activate" \
            "env PYTHONPATH= python${_pyvers} -m virtualenv -p `command -v python${_pyvers}` ${_pyvepath}" \
            'true'; then true \
         && log_error "Fail to create iluvatar corex's app virtualenv: ${_pyvepath}" \
         && false; \
        fi \
     && if ! grep -Fsq corex.sh ${_pyvepath}/bin/activate; then true \
         && true "Some pip wheel build and end user need corex env, so make corex.sh an default activation action" \
         && echo 'if command -v corex.sh >/dev/null 2>&1; then source corex.sh; fi' >> ${_pyvepath}/bin/activate \
         && true; \
        fi \
     && local _G_python_bin_bak=${G_python_bin} \
     && source ${_pyvepath}/bin/activate \
     && setup_pip_flags python \
     && if [ `grep -E "VERSION=\"18.04|ID=ubuntu" /etc/os-release | wc -l | awk '{print $1}'` -eq 2 ]; then true \
         && true "WA onnx build issue by ref: https://github.com/onnx/onnx/issues/3570" \
         && local -a pkgs=( \
                "deb:libprotobuf-dev" \
                "deb:protobuf-compiler" \
            ) \
         && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
         && export CMAKE_ARGS="-DONNX_USE_PROTOBUF_SHARED_LIBS=ON" \
         && true; \
        elif [ `grep -E "VERSION=\"20.04|ID=ubuntu" /etc/os-release | wc -l | awk '{print $1}'` -eq 2 -a "${_pyvers}" == "3.10" ]; then true \
         && true "WA \"pip cannot import html5lib\" error" \
         && get_pip python3 \
         && true; \
        fi \
     && { install_iluvatar_sdk_apps $_release ${_tf_ver} || true; } \
     && ${G_pip_bin} list | grep -i corex | sed -e 's/^/>> /g' | log_lines info \
     && deactivate \
     && setup_pip_flags ${_G_python_bin_bak} \
     && { ((err_cnt-=1)) || true; } \
     && true; \
    done \
 && test ${err_cnt} -eq 0 \
 && true;
}
function setup_repo_mirror_CN_ub() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && true "要先安装ca-certificates，否则有些https的源会fail" \
 && $_sudo apt-get update \
 && do_and_verify \
      'eval pkg_verify_deb ca-certificates apt-transport-https' \
      'eval pkg_install_deb ca-certificates apt-transport-https' \
      "true" \
 && $_sudo sed -i.bak \
        -e 's,https\?://\(archive.ubuntu.com\),https://mirrors.aliyun.com,g' \
        -e 's,//\(archive.ubuntu.com\),//cn.\1,g' \
        -e 's,//\(ports.ubuntu.com\),//cn.\1,g' \
        /etc/apt/sources.list \
 && true;
}
function setup_os() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && $_sudo bash -c 'echo "Asia/Shanghai" >/etc/timezone' \
 && pkgs=( \
        #dmidecode sysstat ipmitool
        "rpm:5:deltarpm" \
        "rpm:5:centos-release-scl" \
        "deb:5:apt-transport-https" \
        "deb:5:apt-utils" \
        "deb:5:ca-certificates" \
        "deb:5:software-properties-common" \
        \
        "deb:8:build-essential" "rpm:8:rpm-build" \
        "deb:8:dpkg-dev"        "rpm:8:createrepo" \
                                "rpm:8:devtoolset-9" \
        \
        "deb:cgroup-tools"      "rpm:libcgroup-tools" \
        "deb:dnsutils"          "rpm:bind-utils" \
        "deb:exuberant-ctags"   "rpm:ctags" \
        "deb:iproute2"          "rpm:iproute" \
        "deb:iputils-ping"      "rpm:iputils" \
        "deb:iputils-tracepath" \
        "deb:locales"           "rpm:glibc-common" \
        "deb:locales-all" \
        "deb:lsb-base"          "#rpm:initscripts" \
        "deb:netcat-openbsd"    "rpm:netcat" \
                                "rpm:nmap-ncat" \
        "deb:openjdk-8-jdk"     "rpm:java-1.8.0-openjdk" \
        "deb:p7zip-full" \
        "deb:pkg-config"        "rpm:pkgconfig" \
        "deb:uuid-runtime"      "rpm:uuid" \
        "deb:libprotobuf-dev" \
        "deb:protobuf-compiler" \
        "deb:collectd-utils" \
                                "rpm:collectd-amqp" \
                                "rpm:collectd-apache" \
                                "rpm:collectd-mysql" \
                                "rpm:collectd-nginx" \
                                "rpm:collectd-ping" \
                                "rpm:collectd-redis" \
                                "rpm:collectd-write_kafka" \
                                "rpm:collectd-write_redis" \
                                "rpm:collectd-zookeeper" \
                                "rpm:collectd-web" \
                                "rpm:collectd-chrony" \
                                "rpm:collectd-ping" \
                                "rpm:collectd-smart" \
                                "rpm:collectd-sensors" \
        \
        "bzip2" \
        "ca-certificates" \
        "ccache" \
        "cmake" \
        "collectd" \
        "cscope" \
        "curl" \
        "duplicity" \
        "file" \
        "git" \
        "gnupg2" \
        "graphviz" \
        # utils.sh里面filter_pkgs等要用
        "gawk" \
        "iotop" \
        "lsof" \
        "maven" \
        "mosh" \
        "net-tools" \
        "nmap" \
        "nmon" \
        "openssh-server" \
        # mpi4py depends
        "deb:libopenmpi-dev"    "rpm:openmpi-devel" \
        "p7zip" \
        "patchelf" \
        "pdsh" \
        "pwgen" \
        "rsync" \
        "screen" \
        "socat" \
        "strace" \
        "stress" \
        "sudo" \
        "sysbench" \
        "tcpdump" \
        "tmux" \
        "tzdata" \
        "deb:vim" "rpm:vim-enhanced" \
        "wget" \
        "zip" \
    ) \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1604=( \
    ) \
 && pkgs_ub1804=( \
    ) \
 && pkgs_ub2004=( \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then \
        pkgs+=(${pkgs_rh7[@]}); \
        # 这个包在rhel里面和系统包有冲突，暂时只在检测到centos时安装
        pkgs+=("rpm:initscripts"); \
    elif grep -sq "PRETTY_NAME=\"Red Hat Enterprise Linux Server 7" /etc/os-release; then \
        pkgs+=(${pkgs_rh7[@]}); \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    elif grep -sq "ID=\"rhel\"" /etc/os-release; then true \
     && install_centos7_repo \
     && true; \
    elif grep -sq "ID=\"centos\"" /etc/os-release; then true \
     && install_epel \
     && enable_epel \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && true "Setup repository 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64's apt-key" \
     && $_sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "0xA4B469963BF863CC" \
     && true; \
    fi \
 && true;
}
function get_pip() {
    true set -x \
 && local _sudo=${sudo:-/usr/bin/sudo} \
 && if [ "`id -u -n`" == "root" -o "$as_root" != "true" ]; then _sudo=""; fi \
 && local _python=${_python:-${1:-python3}} \
 && local _f=`download_by_cache https://bootstrap.pypa.io/get-pip.py` \
 && ${_sudo} ${_sudo:+-n} ${_python} ${_f} \
 && ${_sudo} ${_sudo:+-n} ${_python} -m pip list | grep pip \
 && true; \
}
function setup_python3() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && pkgs_rh7=( \
        "rpm:python3-devel" \
        "rpm:python36-Cython" \
        "rpm:python36-lxml" \
        "rpm:python36-numpy" \
        "rpm:python36-virtualenv" \
        "pip:ipython" \
        "pip:virtualenvwrapper" \
        "rpm:rh-python38" \
        "rpm:rh-python38-python-devel" \
        "rpm:rh-python38-python-Cython" \
        "rpm:rh-python38-python-lxml" \
        "rpm:rh-python38-python-numpy" \
    ) \
 && pkgs_ub1604=( \
        "deb:virtualenv-clone" \
    ) \
 && pkgs_ub1804=( \
        "pip:virtualenvwrapper" \
        "deb:virtualenv-clone" \
        "deb:python3.8" \
        "deb:python3.8-dev" \
        "deb:python3.8-venv" \
    ) \
 && pkgs_ub2004=(
        "deb:python3-virtualenvwrapper"
        "deb:python3-virtualenv-clone"
        # ub2004's python3.6 comes from deadsnakes/ppa
        "deb:python3.6-full"
        "deb:python3.6-dev"
        "deb:python3.10-full"
        "deb:python3.10-dev"
    ) \
 && pkgs=( \
        "python3" \
        "python3-pip" \
        "deb:cython3" \
        "deb:ipython3" \
        "deb:python3-dev" \
        "deb:python3-lxml" \
        "deb:python3-numpy" \
        "deb:python3-setuptools" \
        "deb:python3-virtualenv" \
        "deb:python3-wheel" \
        "deb:virtualenv" \
        "deb:virtualenvwrapper" \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then true \
     && pkgs+=(${pkgs_ub2004[@]}) \
     && $sudo add-apt-repository -y ppa:deadsnakes/ppa \
     && true; \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && pkgs+=(${pkgs_rh7[@]}) \
     && install_epel \
     && true; \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
 && if grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && { cat <<EOF
source /opt/rh/rh-python38/enable
export X_SCLS="\`scl enable rh-python38 'echo $X_SCLS'\`"
EOF
} | $sudo tee /etc/profile.d/python38.sh | sed -e 's/^/>> /g' | log_lines info \
     && local _G_python_bin_bak=${G_python_bin} \
     && source /etc/profile.d/python38.sh \
     && test -n "`command -v python3.8`" \
     && setup_pip_flags python3.8 \
     && pkgs=( \
            "pip:ipython" \
            "pip:virtualenv" \
            "pip:virtualenvwrapper" \
        )  \
     && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
     && setup_pip_flags ${_G_python_bin_bak} \
     && true; \
    elif [ `grep -E "VERSION=\"20.04|ID=ubuntu" /etc/os-release | wc -l | awk '{print $1}'` -eq 2 ]; then true \
     && true "WA \"pip cannot import html5lib\" error" \
     && get_pip python3.10 \
     && true; \
    fi \
 && true;
}
function setup_darwin_deps() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1604=( \
    ) \
 && pkgs_ub1804=( \
    ) \
 && pkgs_ub2004=( \
    ) \
 && pkgs=( \
        "deb:5:apt-transport-https" \
        "ca-certificates" \
        "curl" \
        "deb:libffi-dev"      "rpm:libffi-devel" \
        "deb:libgl1-mesa-glx" \
        "deb:libssl-dev"      "rpm:openssl-devel" \
                              "rpm:openssl11" \
        "deb:libxml2"         "rpm:libxml2" \
        "deb:libxml2-dev"     "rpm:libxml2-devel" \
        "deb:libxslt1.1"      "rpm:libxslt" \
        "deb:libxslt1-dev"    "rpm:libxslt-devel" \
        "deb:lsb-base"        "#rpm:initscripts" \
        "deb:mongodb" \
        "rabbitmq-server" \
        "deb:redis-sentinel" \
        "deb:redis-server"     "rpm:redis" \
        "deb:redis-tools" \
        "deb:zlib1g"           "rpm:zlib" \
        "deb:zlib1g-dev"       "rpm:zlib-devel" \
        "munge" \
        "graphviz" \
        "qrencode" \
        \
        "rpm:munge-devel" \
        "rpm:readline-devel" \
        "rpm:pam-devel" \
        "rpm:mariadb" \
        "rpm:mariadb-devel" \
        "rpm:perl-ExtUtils-MakeMaker" \
        \
        "poppler-utils" \
        "poppler-data" \
        \
        "rpm:wqy-microhei-fonts" "deb:fonts-wqy-microhei" \
        "rpm:wqy-zenhei-fonts"   "deb:fonts-wqy-zenhei" \
        \
        "libreoffice" \
        "deb:libreoffice-l10n-zh-cn" "rpm:libreoffice-langpack-zh-Hans" \
        \
        "deb:libsasl2-dev" "rpm:cyrus-sasl-devel" \
        \
        "gettext" \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && pkgs+=(${pkgs_rh7[@]}) \
     && true "这个包在rhel里面和系统包有冲突，暂时只在检测到centos时安装" \
     && pkgs+=("rpm:initscripts") \
     && install_epel \
     && true; \
    elif grep -sq "PRETTY_NAME=\"Red Hat Enterprise Linux Server 7" /etc/os-release; then true \
     && pkgs+=(${pkgs_rh7[@]}) \
     && install_epel \
     && true; \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' "true" \
 \
 && install_slurm \
 && install_stable_nginx \
 && install_openresty \
 \
 && log_info " " \
 && log_info "Disable services by default" \
 && log_info " " \
 && if [ -f /.dockerenv ]; then true \
     && _cmds="#disable" \
     && true; \
    else true \
     && _cmds="stop mask" \
     && true; \
    fi \
 && if command -v systemctl >/dev/null; then for _cmd in $_cmds; \
    do true \
     && if echo "$_cmd" | grep -sq "^#"; then continue; fi \
     && $_sudo systemctl $_cmd \
            mongodb.service \
            munge.service \
            nginx.service \
            openresty.service \
            rabbitmq-server.service \
            redis-sentinel.service \
            redis-server.service \
            slurmctld.service \
            slurmd.service \
     && true; \
    done; fi \
 && true;
}
function setup_iluvatar_deps() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1804=( \
    ) \
 && pkgs_ub2004=( \
    ) \
 && pkgs_ub2204=( \
    ) \
 && pkgs=( \
        "deb:5:apt-transport-https" \
        "ca-certificates" \
        "curl" \
        "deb:libffi-dev"      "rpm:libffi-devel" \
        "deb:libssl-dev"      "rpm:openssl-devel" \
                              "rpm:openssl11" \
        "deb:lsb-base"        "#rpm:initscripts" \
        "deb:zlib1g"           "rpm:zlib" \
        "deb:zlib1g-dev"       "rpm:zlib-devel" \
        "deb:libpci-dev" \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "VERSION=\"22.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2204[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && pkgs+=(${pkgs_rh7[@]}) \
     && true "这个包在rhel里面和系统包有冲突，暂时只在检测到centos时安装" \
     && pkgs+=("rpm:initscripts") \
     && install_epel \
     && true; \
    elif grep -sq "PRETTY_NAME=\"Red Hat Enterprise Linux Server 7" /etc/os-release; then true \
     && pkgs+=(${pkgs_rh7[@]}) \
     && install_epel \
     && true; \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' "true" \
 && true;
}
function setup_opencv() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1604=( \
    ) \
 && pkgs_ub1804=( \
        "deb:python3-opencv" \
        "deb:python3-willow" \
    ) \
 && pkgs_ub2004=( \
        "deb:python3-opencv" \
        "deb:python3-willow" \
    ) \
 && pkgs=( \
            "rpm:opencv" \
            "rpm:opencv-python" \
            "rpm:opencv-devel" \
        "ffmpeg" \
        "deb:libavcodec-dev" \
        "deb:libavformat-dev" \
        "deb:libgstreamer-plugins-base1.0-dev" \
                                  "rpm:gstreamer-plugins-base-devel" \
                                  "rpm:gstreamer-plugins-bad-free-devel" \
        "deb:libgstreamer1.0-dev" "rpm:gstreamer-devel" \
        "deb:libgtk-3-dev"        "rpm:gtk3-devel" \
        "deb:libjpeg-dev"         "rpm:libjpeg-turbo-devel" \
        "deb:libopenexr-dev"      "rpm:OpenEXR-devel" \
        "deb:libpng-dev"          "rpm:libpng-devel" \
        "deb:libswscale-dev" \
        "deb:libtiff-dev"         "rpm:libtiff-devel" \
        "deb:libwebp-dev"         "rpm:libwebp-devel" \
        "deb:pkg-config"          "rpm:pkgconfig" \
        "deb:python3-pil"         "rpm:python36-pillow" \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then \
        pkgs+=(${pkgs_rh7[@]}); \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && true "ffmpeg comes from rpmfusion repo" \
     && install_rpmfusion_free \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
 && true;
}
function setup_tf_deps() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1604=( \
        "deb:libhdf5-serial-dev" \
    ) \
 && pkgs_ub1804=( \
        "deb:libhdf5-serial-dev" \
    ) \
 && pkgs_ub2004=( \
    ) \
 && pkgs=( \
        "deb:hdf5-tools"         "rpm:hdf5" \
        "deb:libhdf5-dev"        "rpm:hdf5-devel" \
        "deb:libjpeg8-dev"       "rpm:libjpeg-turbo-devel" \
        "deb:zlib1g-dev"         "rpm:zlib-devel" \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then \
        pkgs+=(${pkgs_rh7[@]}); \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
 && true;
}
function setup_xfce_xrdp() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1604=( \
    ) \
 && pkgs_ub1804=( \
    ) \
 && pkgs_ub2004=( \
    ) \
 && pkgs=( \
        "deb:10:xfce4"
        "xfce4-clipman-plugin"
        "xfce4-cpugraph-plugin"
        "xfce4-netload-plugin"
        "xfce4-screenshooter"
        "xfce4-taskmanager"
        "xfce4-terminal"
        "xfce4-xkb-plugin"
        "sudo"
        "wget"
        "xorgxrdp"
        "xrdp"
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then \
        pkgs+=(${pkgs_rh7[@]}); \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true "TODO: danchitnis/container-xrdp原来的Dockerfile隐含依赖--install-recommends，现在还没搞清楚，暂时也用" \
     && local apt_install_flags="-y" \
     && true; \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && true "Centos install Xfce by group" \
     && $_sudo yum -y groups install "Xfce" \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && pkgs=(`dpkg -l light-lock xscreensaver | grep "^ii" | awk '{print $2}' | xargs`) \
     && if [ ${#pkgs[@]} -gt 0 ]; then $_sudo ${G_apt_bin} remove -y ${pkgs[@]}; fi \
     && $_sudo ${G_apt_bin} autoremove -y \
     && true; \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && { $_sudo yum erase -y xscreensaver || true; } \
     && true; \
    fi \
 && local run_sh=`download_by_cache "https://github.com/danchitnis/container-xrdp/raw/master/build/ubuntu-run.sh"` \
 && $_sudo cp -p ${run_sh} /usr/bin/run.sh \
 && $_sudo chmod a+x /usr/bin/run.sh \
 && $_sudo mkdir /var/run/dbus \
 && $_sudo cp /etc/X11/xrdp/xorg.conf /etc/X11 \
 && $_sudo sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && $_sudo sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config \
     && $_sudo bash -c "echo xfce4-session >> /etc/skel/.Xsession" \
     && true; \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then true \
     && $_sudo bash -c "echo 'allowed_users = anybody' >> /etc/X11/Xwrapper.config" \
     && $_sudo bash -c "echo xfce4-session >> /etc/skel/.Xclients; chmod a+x /etc/skel/.Xclients;" \
     && true; \
    fi \
 && true;
}
function setup_deepstream() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && local CUDNN_VERSION=${CUDNN_VERSION:-8.7.0.84-1+cuda11.8} \
 && local TENSORRT_VERSION=${TENSORRT_VERSION:-8.5.2-1+cuda11.8} \
 && pkgs_rh7=( \
    ) \
 && pkgs_ub1604=( \
    ) \
 && pkgs_ub1804=( \
    ) \
 && pkgs_ub2004=( \
        # from https://docs.nvidia.com/metropolis/deepstream/dev-guide/text/DS_docker_containers.html
        "deb:10:pkg-config"
        "deb:10:libglvnd-dev"
        "deb:10:libgl1-mesa-dev"
        "deb:10:libegl1-mesa-dev"
        "deb:10:libgles2-mesa-dev"
        "deb:10:wget"
        "deb:10:libyaml-cpp-dev"
        "deb:10:gnutls-bin"
        "deb:10:linux-libc-dev"
        "deb:10:libglew2.1"
        "deb:10:libssl1.1"
        "deb:10:libjpeg8"
        "deb:10:libjson-glib-1.0-0"
        "deb:10:gstreamer1.0-plugins-good"
        "deb:10:gstreamer1.0-plugins-bad"
        "deb:10:gstreamer1.0-plugins-ugly"
        "deb:10:gstreamer1.0-tools"
        "deb:10:gstreamer1.0-libav"
        "deb:10:gstreamer1.0-alsa"
        "deb:10:libcurl4"
        "deb:10:libuuid1"
        "deb:10:libjansson4"
        "deb:10:libjansson-dev"
        "deb:10:librabbitmq4"
        "deb:10:libgles2-mesa"
        "deb:10:libgstrtspserver-1.0-0"
        "deb:10:libv4l-dev"
        "deb:10:gdb"
        "deb:10:bash-completion"
        "deb:10:libboost-dev"
        "deb:10:uuid-dev"
        "deb:10:libgstrtspserver-1.0-0"
        "deb:10:libgstrtspserver-1.0-0-dbg"
        "deb:10:libgstrtspserver-1.0-dev"
        "deb:10:libgstreamer1.0-dev"
        "deb:10:libgstreamer-plugins-base1.0-dev"
        "deb:10:libglew-dev"
        "deb:10:libssl-dev"
        "deb:10:libopencv-dev"
        "deb:10:freeglut3-dev"
        "deb:10:libjpeg-dev"
        "deb:10:libcurl4-gnutls-dev"
        "deb:10:libjson-glib-dev"
        "deb:10:libboost-dev"
        "deb:10:librabbitmq-dev"
        "deb:10:libgles2-mesa-dev"
        "deb:10:pkg-config"
        "deb:10:libxau-dev"
        "deb:10:libxdmcp-dev"
        "deb:10:libxcb1-dev"
        "deb:10:libxext-dev"
        "deb:10:libx11-dev"
        "deb:10:libnss3"
        "deb:10:linux-libc-dev"
        "deb:10:git"
        "deb:10:wget"
        "deb:10:gnutls-bin"
        "deb:10:sshfs"
        "deb:10:python3-distutils"
        "deb:10:python3-apt"
        "deb:10:python"
        "deb:10:rsyslog"
        "deb:10:vim"
        "deb:10:rsync"
        "deb:10:gstreamer1.0-rtsp"
        "deb:10:libcudnn8=${CUDNN_VERSION}"
        "deb:10:libcudnn8-dev=${CUDNN_VERSION}"
        "deb:10:libnvinfer8=${TENSORRT_VERSION}"
        "deb:10:libnvinfer-dev=${TENSORRT_VERSION}"
        "deb:10:libnvparsers8=${TENSORRT_VERSION}"
        "deb:10:libnvparsers-dev=${TENSORRT_VERSION}"
        "deb:10:libnvonnxparsers8=${TENSORRT_VERSION}"
        "deb:10:libnvonnxparsers-dev=${TENSORRT_VERSION}"
        "deb:10:libnvinfer-plugin8=${TENSORRT_VERSION}"
        "deb:10:libnvinfer-plugin-dev=${TENSORRT_VERSION}"
        "deb:10:python3-libnvinfer=${TENSORRT_VERSION}"
        "deb:10:python3-libnvinfer-dev=${TENSORRT_VERSION}"
        "deb:10:libx11-xcb-dev"
        "deb:10:libxkbcommon-dev"
        "deb:10:libwayland-dev"
        "deb:10:libxrandr-dev"
        "deb:10:libegl1-mesa-dev"
    ) \
 && pkgs=( \
    ) \
 && cat /etc/os-release | sed -e 's/^/>> /g' | log_lines info \
 && if grep -sq "VERSION=\"16.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1604[@]}); \
    elif grep -sq "VERSION=\"18.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub1804[@]}); \
    elif grep -sq "VERSION=\"20.04" /etc/os-release; then \
        pkgs+=(${pkgs_ub2004[@]}); \
    elif grep -sq "CentOS Linux 7" /etc/os-release; then \
        pkgs+=(${pkgs_rh7[@]}); \
    fi \
 && if grep -sq "ID=ubuntu" /etc/os-release; then true \
     && if [ "${_BLD_REGION}" = "CN" ]; then true \
         && setup_repo_mirror_CN_ub \
         && true; \
        fi \
     && $_sudo apt-get update \
     && true; \
    fi \
 && do_and_verify 'eval pkg_verify ${pkgs[@]}' 'eval pkg_install ${pkgs[@]}' 'true' \
 && true;
}
function download_os_pkgs() {
    if $is_rhel; then
        download_os_pkgs_rh $@
    elif $is_ubuntu; then
        download_os_pkgs_ubuntu $@
    fi
}
function _continue_lines_blank() {
    awk '
        BEGIN {
            line="";
            cnt=0;
        }
        /^[^ ]/ {
            if(cnt>0){
                print line;
            }
            line=$0;
            cnt=1;
        }
        /^[ ]/ {
            line=line$0;
            cnt+=1;
            next;
        }
        END{
            print line;
        }
    '
}
function download_os_pkgs_rh() {
    # 常用参数--verbose --version=false
    local _arg
    local -a _arg_stage=()
    local _version=true
    local _sudo=$sudo
    if [ "$as_root" != "true" ]; then
        _sudo=""
    fi
    for _arg in $@
    do
        if echo "$_arg" | grep -sq "^--version="; then
            _version=`echo $_arg | cut -d= -f2`
            continue
        fi
        _arg_stage+=("$_arg")
    done
    # * 带arch后缀的，就不要限定了，因为yum终将自己选择
    # * N:xxx-xxx-xx的，前面的N看起来不是我们想要的。# TODO: 那是啥？
    # * 连续的空格，用-接上，这样pkg名字和version就接上了
    local -a pkgs=($($_sudo yum list installed | grep -A99999 "^Installed Packages" | tail -n+2 | \
        _continue_lines_blank | \
        if $_version; then
            awk '{print $1,$2}'
        else
            awk '{print $1}'
        fi | \
        sed -e "s/\.`arch` \+/ /" \
            -e "s/\.noarch \+/ /" \
            -e "s/ \+[0-9]\+:/-/g" \
            -e "s/ \+/-/g"
    ))
    # log for debug only
    if declare -F log_lines >/dev/null 2>&1; then
        log_info "#pkgs=${#pkgs[@]}"
        declare -p pkgs | log_lines info;
    fi
    $_sudo yumdownloader ${_arg_stage[@]} ${pkgs[@]}
}
function download_os_pkgs_ubuntu() {
    # 常用参数--verbose --version=false
    local _arg
    local -a _arg_stage=()
    local _version=true
    for _arg in $@
    do
        if echo "$_arg" | grep -sq "^--version="; then
            _version=`echo $_arg | cut -d= -f2`
            continue
        fi
        _arg_stage+=("$_arg")
    done
    function _filter_arch() {
        sed -e 's/x86_64/amd64/g'
    }
    local _ARCH="`echo "$ARCH" | _filter_arch`"
    function _filter_arch() {
        sed -e "s/:${_ARCH}=/=/" -e "s/:${_ARCH}$//g"
    }
    local -a pkgs=($(
        dpkg -l | grep -A99999 "========" | tail -n+2 | \
        if $_version; then
            awk '{print $2"="$3}'
        else
            awk '{print $2}'
        fi | \
        # 统一去掉arch，这样方便后续exclude那些下载不了的pkgs
        _filter_arch
    ))
    if ! $_version; then
        apt-get download ${_arg_stage[@]} ${pkgs[@]}
    # NOTE:
    #     以下注释掉的代码是一个不成功的尝试，apt-get download会因为某一个不能下载的包，
    #     而拒绝下载其他能下载的包而失败退出，这不是我期望的
    #elif false; then
    #    declare -g err_cnt_nato7Pho=0
    #    function _download() {
    #        if apt-get download ${_arg_stage[@]} $@; then
    #            declare -g err_cnt_nato7Pho=$((err_cnt_nato7Pho+1))
    #        fi
    #    }
    #    for_each_op --silent _download -- ${pkgs[@]}
    #    test ${err_cnt_nato7Pho} -eq 0
    else
        # E: Can't find a source to download version '1:2.31.1-0.4ubuntu3.4' of 'bsdutils:amd64'
        log_debug "Try downloading ${#pkgs[@]} original pkgs"
        declare -p pkgs | sed -e 's/^/>> /g' | log_lines debug
        local lines=`apt-get download ${_arg_stage[@]} ${pkgs[@]} 2>&1`
        local -a bad_pkgs=($(echo "$lines" | \
            grep "E: Can't find a source to download version" | \
            awk -F\' '{print $5"="$3}' | \
            # 统一去掉arch，这样方便后续exclude那些下载不了的pkgs
            _filter_arch
        ))

    if [ ${#bad_pkgs[@]} -gt 0 ]; then
            log_warn "Exclude ${#bad_pkgs[@]} bad pkgs"
            echo "$lines" | grep "E: Can't find a source to download version" | log_lines warn
            apt-cache madison `for _pkg in ${bad_pkgs[@]}; do echo "${_pkg}" | cut -d= -f1; done | xargs` 2>&1 | log_lines warn
            local -a pkgs=`set_difference pkgs[@] bad_pkgs[@]`
    fi

        log_debug "Downloading ${#pkgs[@]} good pkgs"
        apt-get download ${_arg_stage[@]} ${pkgs[@]}
    fi
}
function generate_self_signed_ssl_certificate() {
    # $ vim openssl.cnf
    # [req]
    # default_bits       = 2048
    # default_keyfile    = localhost.key
    # distinguished_name = req_distinguished_name
    # req_extensions     = req_ext
    # x509_extensions    = v3_ca

    # [req_distinguished_name]
    # countryName                 = Country Name (2 letter code)
    # countryName_default         = US
    # stateOrProvinceName         = State or Province Name (full name)
    # stateOrProvinceName_default = New York
    # localityName                = Locality Name (eg, city)
    # localityName_default        = Rochester
    # organizationName            = Organization Name (eg, company)
    # organizationName_default    = localhost
    # organizationalUnitName      = organizationalunit
    # organizationalUnitName_default = Development
    # commonName                  = Common Name (e.g. server FQDN or YOUR name)
    # commonName_default          = localhost
    # commonName_max              = 64

    # [req_ext]
    # subjectAltName = @alt_names

    # [v3_ca]
    # subjectAltName = @alt_names

    # [alt_names]
    # DNS.1   = localhost
    # DNS.2   = 127.0.0.1
    local SSL_KEY_OUT_FILE=${SSL_KEY_OUT_FILE:-localhost.key}
    local SSL_CRT_OUT_FILE=${SSL_CRT_OUT_FILE:-localhost.crt}
    local SSL_KEY_PARAM=${SSL_KEY_PARAM:-"rsa:2048"}
    local SSL_CRT_DAYS=${SSL_CRT_DAYS:-365}
    local SSL_CRT_SUBJ=${SSL_CRT_SUBJ:-"/C=CN/ST=Zhenjiang/L=Jiangsu/O=myCorp/OU=myDept/CN=myTestHost"}
    local SSL_CNF_FILE=
    true \
    && if do_and_verify \
        'command -v openssl' \
        'pkg_install openssl' \
        'true'; then true \
     && pkg_list_installed openssl \
     && true
    else true \
     && log_error "Fail to install \"openssl\" package before trying to generate ssl certificate" \
     && false
    fi \
    && print_title "Generate self-signed ssl certificate \"$SSL_CRT_OUT_FILE\"" \
    && true 'openssl req -new -newkey rsa:2048 -nodes -out myTestHost.csr -keyout myTestHost.key -subj "/C=CN/ST=Zhenjiang/L=Jiangsu/O=myCorp/OU=myDept/CN=myTestHost"' \
    && openssl req \
        -x509 \
        -nodes \
        -days $SSL_CRT_DAYS \
        -subj "${SSL_CRT_SUBJ}" \
        -newkey "${SSL_KEY_PARAM}" \
        -keyout "${SSL_KEY_OUT_FILE}" \
        -out "${SSL_CRT_OUT_FILE}" \
        ${SSL_CNF_FILE:+"-config"} ${SSL_CNF_FILE:+"${SSL_CNF_FILE}"} \
        -batch \
    && ls -ld "${SSL_KEY_OUT_FILE}" "${SSL_CRT_OUT_FILE}"
}
function separate_python_code() {
    local py_file=$1
    local module_name=$2
    if [ -z "$module_name" ]; then
        module_name=`basename $py_file .py`
    fi

    local last_lnum=0
    local last_name=""
    local prolog=""
    local module_file=""
    local func_file=""
    local func_file_shadow=""

    {
        grep -n -E "^def|^class" $py_file | cut -d\( -f1 | sed -e 's/:def */ /g' -e 's/:class */ /g';
        echo "99999999 _THE_END_";
    } | \
    while read lnum name;
    do true \
     && if [ ${last_lnum} -eq 0 ]; then
            prolog=`sed -n "1,$((lnum-1))p" $py_file`
            last_lnum=$lnum
            last_name=$name
            continue
        fi \
     && if [ ! -d "${module_name}" ]; then mkdir -p ${module_name}; fi \
     && module_file=${module_name}/__init__.py \
     && if [ ! -f "${module_file}" ]; then true \
         && {
                echo "#! /usr/bin/env python"
                echo "# -*- coding: utf-8 -*-"
                echo ""
                echo ""
                echo "# _beg_of_import_sub_modules_"
                echo "# _end_of_import_sub_modules_"
                echo ""
                echo ""
                echo "__all__ = ["
                echo "]"
            } > ${module_file} \
         && true; \
        fi \
     && func_file=${module_name}/${last_name}.py \
     && func_file_shadow=${module_name}/.${last_name}.py \
     && {
            echo "$prolog"
            echo ""
            echo ""
            echo "__all__ = ["
            echo "    \"${last_name}\","
            echo "]"
            echo ""
            echo ""
            sed -n "${last_lnum},$((lnum-1))p" $py_file
        } > ${func_file_shadow} \
     && if ! grep -sq "^from .${last_name} import" ${module_file}; then true \
         && sed -i -e "s/^\(# _end_of.*\)$/from .${last_name} import *\n\1/g" ${module_file} \
         && true; \
        fi \
     && if ! grep -sq "^ *\"${last_name}\",$" ${module_file}; then true \
         && sed -i -e "s/^]$/    \"${last_name}\",\n]/g" ${module_file} \
         && true; \
        fi \
     && if [ -s ${func_file} ]; then true \
         && if ! cmp ${func_file} ${func_file_shadow}; then true \
             && true; \
            fi \
         && true; \
        else true \
         && mv ${func_file_shadow} ${func_file} \
         && true; \
        fi \
     && wc -l ${func_file} | sed -e 's/^/>> /g' >&2 \
     && last_lnum=$lnum \
     && last_name=$name \
     && true; \
    done
}
function wait_for_lanhost_up() {
    #
    # 等待同网段主机上线
    # 这个会探测目标主机的一个端口，默认是22，但不需要这个端口一定在目标主机开放
    # 这只是发送一个探测，lanhost_up后续依赖本机是否检测到这个lanhost的arp条目来确定
    # 这个lanhost已经起来了
    # Usage: $0 HOST [TIMEOUT:-2] [TEST_PORT:-22]
    # rc=0 if succ else 1
    #
    local host=$1
    local timeout=${2:-2}
    local test_port=${test_port:-22}
    local succ=1
    local rarp=false
    local nc=nc
    while [ ${timeout} -gt 0 ];
    do
        # 尝试联通服务端口，成功的话，当然就成了
        # 否则，看arp请求是否回来了，这也代表主机网卡起来了
        _line=`arp -na $host 2>/dev/null`
        if echo ${_line} | grep -sq " at [a-fA-F0-9:-]\+ .* on "; then
            succ=0
            break
        elif ! $rarp || echo ${_line} | grep -sqF " at <incomplete> on "; then
            echo "[D]: Host \"$host\" seems down. Wait 1s and try next time(${timeout})." >&2
            nc -z -w 1 $host ${test_port} 2>/dev/null || true
            ((timeout-=1))
            if ! $rarp; then rarp=true; fi
        elif $rarp; then
            echo "[W]: unexpected arp resp: \"${_line}\", assume fail." >&2
            break
        fi
    done
    (exit $succ)
}
function __test_wait_for_lanhost_up() {
    local err_cnt=0
    local func=wait_for_lanhost_up

    # 对于不可能探测的主机，返回失败
    beg=`date "+%s"`
    $func 8.8.8.8 10 && { ((err_cnt+=1)); log_error "fail case 1.1"; }
    ((dur=`date "+%s"`-beg))
    # 对于不可能探测的主机，快速返回，不要等到超时
    log_debug "case 1.2 dur=${dur}"
    [ $dur -le 2 ] || { ((err_cnt+=1)); log_error "fail case 1.2: dur, 2 vs. ${dur}"; }

    # 本机网关，理应存在，期望成功
    gw_ip=`ip route get 8.8.8.8 | grep via | awk '{print $3}'`
    beg=`date "+%s"`
    $func $gw_ip 10 || { ((err_cnt+=1)); log_error "fail case 2.1"; }
    ((dur=`date "+%s"`-beg))
    log_debug "case 2.2 dur=${dur}"
    # 本机网关，理应存在，很快成功
    [ $dur -le 3 ] || { ((err_cnt+=1)); log_error "fail case 2.2: dur, 3 vs. ${dur}"; }

    test $err_cnt -eq 0
}
function wait_for_service_up() {
    #
    # 等待目标服务上线
    # Usage: $0 HOST PORT [TIMEOUT:-2]
    # rc=0 if succ else 1
    #
    local host=$1
    local port=$2
    local timeout=${3:-2}
    local succ=1
    local nc=nc
    if ! command -v $nc >/dev/null 2>&1; then
        nc=ncat
    fi
    while [ ${timeout} -gt 0 ];
    do
        if nc -zv -w 1 ${host} ${port} 2>/dev/null; then
            succ=0
            break
        else
            echo "[D]: Service \"$host:${port}\" seems down. Wait 1s and try next time(${timeout})." >&2
            sleep 1
            ((timeout-=1))
        fi
    done
    (exit $succ)
}
function __test_wait_for_service_up() {
    local err_cnt=0
    local func=wait_for_service_up

    # 对于不可能探测的服务，返回失败
    beg=`date "+%s"`
    $func 8.8.8.8 22 4 && { ((err_cnt+=1)); log_error "fail case 1.1"; }
    ((dur=`date "+%s"`-beg))
    # 对于不可能探测的主机，一定超时才返回
    log_debug "case 1.2 dur=${dur}"
    [ $dur -ge 4 ] || { ((err_cnt+=1)); log_error "fail case 1.2: dur, 4 vs. ${dur}"; }

    # 对于公开的服务，期望成功
    beg=`date "+%s"`
    $func www.baidu.com 80 4 || { ((err_cnt+=1)); log_error "fail case 2.1"; }
    ((dur=`date "+%s"`-beg))
    # 对于公开的服务，合理时间内返回，绝对不应该接近超时
    log_debug "case 2.2 dur=${dur}"
    [ $dur -lt 4 ] || { ((err_cnt+=1)); log_error "fail case 2.2: dur, 4 vs. ${dur}"; }

    test $err_cnt -eq 0
}
function fix_pyvirtualenv() {
    true \
 && local _VIRTUAL_ENV=${1:-${VIRTUAL_ENV}} \
 && if [ ! -d "${_VIRTUAL_ENV}" ]; then true \
     && log_error "Target VIRTUAL_ENV(${_VIRTUAL_ENV}) does not exists. Abort!" \
     && false;
    fi \
 && true "------------------------------------------------------------" \
 && true "Restore previous modifications" \
 && local _err_cnt=0 \
 && local _FILE \
 && for _FILE in `find ${_VIRTUAL_ENV}/bin -name "*.bak" | xargs`; do mv -vf ${_FILE} ${_FILE%*.bak} || { ((_err_cnt+=1)); break; }; done \
 && test ${_err_cnt} -eq 0 \
 && true "Fix VIRTUAL_ENV dir in pip virtualenv" \
 && local _CUR_DIR=`grep "^VIRTUAL_ENV=" ${_VIRTUAL_ENV}/bin/activate | cut -d= -f2 | sed -e "s/[\"']//g"` \
 && for _FILE in `grep -rF "$_CUR_DIR" ${_VIRTUAL_ENV}/bin 2>/dev/null | cut -d: -f1 | sort -u | grep -vE "\.bak$|Binary file"`; do true \
     && if ! sed -i.bak -e "s,${_CUR_DIR},${_VIRTUAL_ENV},g" ${_FILE}; then ((_err_cnt+=1)); break; fi \
     && if cmp -s ${_FILE}.bak ${_FILE}; then rm -f ${_FILE}.bak; fi \
     && true; \
    done \
 && test ${_err_cnt} -eq 0 \
 && true "------------------------------------------------------------" \
 && true "Fix broken python* symbol links" \
 && local _py_bin=`ls -1d ${_VIRTUAL_ENV}/bin/python3.[0-9]*` \
 && test -n "${_py_bin}" -a -e "${_py_bin}" \
 && _py_bin=${_py_bin##*/} \
 && for _FILE in `find ${_VIRTUAL_ENV}/bin -type l ! -readable`; do true \
     && if rm -f ${_FILE} && ln -vs ${_py_bin} ${_FILE}; then true; else true \
         && log_error "Fail to fix broken symbol link: ${_FILE}. Do it manually. Abort!" \
         && ((_err_cnt+=1)) \
         && break; \
        fi \
     && true; \
    done \
 && test ${_err_cnt} -eq 0 \
 && true;
}
function detach_pci_dev() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then true \
     && _sudo="" \
     && true; \
    fi \
 && local pci_addr=$1 \
 && if [ -z "${pci_addr}" ]; then true \
     && log_error "Empty target pci devices, Abort!" \
     && false; \
    fi \
 && pci_addr=$(echo "$pci_addr" | tr 'A-Z' 'a-z') \
 && true '$ lspci -nnk -s 0000:a0:00.0' \
 && true 'a0:00.0 Processing accelerators [1200]: Device [1e3e:0002]' \
 && true 'Kernel driver in use: vfio-pci' \
 && true 'Kernel modules: bi_driver' \
 && local dev_drv_cur=`lspci -nnk -s ${pci_addr} | grep "Kernel driver in use:" | sed -e 's/^.*in use: *//g'` \
 && if [ -n "${dev_drv_cur}" -a "${dev_drv_cur}" != "vfio-pci" ]; then true \
     && if ! $_sudo bash -c "echo ${pci_addr} >'/sys/bus/pci/drivers/${dev_drv_cur}/unbind'"; then true \
         && log_error "Fail to unbind pci device(${pci_addr}) from its current kernel driver \"${dev_drv_cur}\". Abort!" \
         && false; \
        fi \
     && if ! $_sudo bash -c "echo vfio-pci >'/sys/bus/pci/devices/${pci_addr}/driver_override'"; then true \
         && log_error "Fail to override pci device(${pci_addr})'s driver to \"vfio-pci\". Abort!" \
         && false; \
        fi \
     && if ! $_sudo bash -c "echo ${pci_addr} >/sys/bus/pci/drivers/vfio-pci/bind"; then true \
         && log_error "Fail to bind pci device(${pci_addr}) to driver \"vfio-pci\". Abort!" \
         && false; \
        fi \
     && true; \
    elif [ -z "${dev_drv_cur}" ]; then true \
     && log_error "Fail to find pci device(${pci_addr}) in \"lspci -nnk -s ${pci_addr}\" cmd. Abort!" \
     && false; \
    fi \
 && lspci -nnk -s ${pci_addr} | sed -e 's/^/>> [lspci]: /g' | log_lines info \
 && local nodedev_name=`$_sudo virsh nodedev-list --cap pci | grep pci_$(echo ${pci_addr} | tr ':.' '_')` \
 && if [ -n "${nodedev_name}" ]; then true \
     && if ! $_sudo virsh nodedev-detach ${nodedev_name}; then true \
         && log_error "Fail to detach pci device(${pci_addr}) from virsh's nodedev-list. Abort!" \
         && false; \
        fi \
     && true; \
    else true \
     && log_error "Fail to find pci device(${pci_addr}) in \"virsh nodedev-list\" cmd. Abort!" \
     && false; \
    fi \
 && true;
}
function supermicro_rcmd() {
    true \
 && local _ssh_config=${_ssh_config:-~/.ssh/config} \
 && local _rp_tgt=${1} && shift \
 && local _rp_user="ADMIN" \
 && if [ "x${1}" != "x--" -a -n "${1}" ]; then _rp_user=${1}; shift; fi \
 && local _SSHPASS="${SSHPASS}" \
 && if [ "x${1}" != "x--" -a -n "${1}" ]; then _SSHPASS="${1}"; shift; fi \
 && if [ "x${1}" != "x--" -o $# -lt 2 ]; then log_error "Invalid args \"$@\""; false; fi \
 && shift \
 && local _rp_cmd="${@}" \
 && if [ -z "${_SSHPASS}" ]; then true \
     && _SSHPASS=$(grep -A999 "Host ${_rp_tgt}$" ${_ssh_config} | grep "BMC PWD:" | \
                   head -n1 | cut -d: -f2 | awk '{print $1}') \
     && test -n "${_SSHPASS}" \
     && true; \
    fi \
 && env SSHPASS=${_SSHPASS} \
    sshpass -e bash -c "echo -e '${_rp_cmd}' | ssh -oConnectTimeout=4 ${_rp_tgt} -l${_rp_user}" \
 && true; \
}
function rpower_query_supermicro() { supermicro_rcmd $@ -- "show system1/pwrmgtsvc1"; }
function rpower_status_supermicro() {
    # PowerState=1(ON) | 6 (OFF)
    true \
 && local _lines=$(rpower_query_supermicro $@ 2>&1) \
 && local _PowerState=`echo "$_lines" | grep "^ *PowerState=[0-9]$" | cut -d= -f2` \
 && if [ -z "${_PowerState}" ]; then true \
     && log_error "Fail to get power status of \"${_rp_tgt}\", detail responses are:" \
     && echo "${_lines}" | sed -e 's/^/>> /g' | log_lines warn \
     && false; \
    elif [ "${_PowerState}" == "1" ]; then echo "ON"; \
    elif [ "${_PowerState}" == "6" ]; then echo "OFF"; \
    else log_error "Unknown power state \"${_PowerState}\""; false; \
    fi \
 && true; \
}
function rpower_on_supermicro() { supermicro_rcmd $@ -- "cd system1/pwrmgtsvc1\nstart"; }
function rpower_off_supermicro() { supermicro_rcmd $@ -- "cd system1/pwrmgtsvc1\nstop"; }
function rpower_reset_supermicro() { supermicro_rcmd $@ -- "cd system1/pwrmgtsvc1\nreset"; }
function gensudo() {
    true \
 && local _sudo=${sudo:-sudo} \
 && if [ "$as_root" != "true" ]; then _sudo=""; fi \
 && local _USER=${_USER:-${1:-${USER:-`whoami`}}} \
 && lines="Defaults:$_USER !requiretty
$_USER ALL=(ALL) NOPASSWD:ALL" \
 && if [ "$_USER" != "root" -a ! -f /etc/sudoers.d/$_USER ]; then true \
     && echo "$lines" | sudo tee /etc/sudoers.d/$_USER \
     && true; \
    fi \
 && true; \
}
function _smart_link() {
    true \
 && if [ "x${1}" == "x--dry-run" ]; then _dry_run_prefix="echo"; shift; fi \
 && if [ "x${1}" == "x--" ]; then shift; fi \
 && local _entry=$(eval "echo $`seq -s:\$ 1 $#`") \
 && local _src=`echo "${_entry}" | cut -d: -f1` \
 && local _dst=`echo "${_entry}" | cut -d: -f2 -s` \
 && local _mandatory=`echo "${_entry}" | cut -d: -f3 -s` \
 && local _own=`echo "${_entry}" | cut -d: -f4 -s` \
 && local _grp=`echo "${_entry}" | cut -d: -f5 -s` \
 && local _own_self=`id -n -u` \
 && local _grp_self=`id -n -g` \
 && if [ "x${_own}" == "x${_own_self}" ]; then _own=""; fi \
 && if [ "x${_grp}" == "x${_grp_self}" ]; then _grp=""; fi \
 && true "# 没指定grp的话，取own的grp" \
 && if [ -z "${_grp}" -a -n "${_own}" ]; then _grp=`id -n -g ${_own}`; fi \
 && true "# 目标目录已经存在，下一个" \
 && true "# 存在的话，如果需要，也强制复位own和grp" \
 && if [ -n "${_dst}" -a -d "${_dst}" ]; then true \
     && if [ -n "${_mandatory}" -a -n "${_own}" ]; then true \
         && ${_dry_run_prefix} ${sudo} chown ${_own} `if [ -d ${_dst} ]; then echo "${_dst}/"; else echo "${_dst}"; fi` \
         && true; \
        fi \
     && if [ -n "${_mandatory}" -a -n "${_grp}" ]; then true \
         && ${_dry_run_prefix} ${sudo} chgrp ${_grp} `if [ -d ${_dst} ]; then echo "${_dst}/"; else echo "${_dst}"; fi` \
         && true; \
        fi \
     && log_debug "Skip mnt entry: \"${_entry}\"" \
     && continue; \
    else true \
     && log_debug "Process mnt entry: \"${_entry}\"" \
     && true; \
    fi \
 && true "# 确保源目录存在，否则创建" \
 && if ! if [ \
        -n "${_mandatory}" \
        -a -n "${_src}" -a ! -d "${_src}" \
    ]; then true \
     && log_debug "Create mandatory src: \"${_entry}\"" \
     && if [ -L "${_src}" ]; then rm -f ${_src}; fi \
     && mkdir -p ${_src} \
     && if [ -n "${_own}" ]; then true \
         && chown ${_own} `if [ -d ${_src} ]; then echo "${_src}/"; else echo "${_src}"; fi` \
         && true; \
        fi \
     && if [ -n "${_grp}" ]; then true \
         && chgrp ${_grp} `if [ -d ${_src} ]; then echo "${_src}/"; else echo "${_src}"; fi` \
         && true; \
        fi \
     && ls -ld ${_src} | sed -e 's/^/[src]: >> /g' | log_lines info \
     && true; \
    fi; then true \
     && log_error "Fail to create mandatory src: \"${_entry}\"" \
     && ls -ld ${_src} | sed -e 's/^/[src]: >> /g' | log_lines error \
     && false; \
    fi \
 && true "# 把源目录连接到目标，仅当目标不存在时" \
 && if ! if [ -n "${_src}" -a -d "${_src}" \
        -a -n "${_dst}" -a ! -e "${_dst}" \
    ]; then true \
     && log_debug "Link src to mandatory dst: \"${_entry}\"" \
     && { rm -f ${_dst} 2>/dev/null || true; } \
     && if [ "`dirname ${_src}`" == "`dirname ${_dst}`" ]; then true \
         && ln -s `basename ${_src}` ${_dst} \
         && true; \
        else true \
         && ln -s ${_src} ${_dst} \
         && true; \
        fi \
     && ls -ld ${_dst} | sed -e 's/^/[dst]: >> /g' | log_lines info \
     && true; \
    fi; then true \
     && log_error "Fail to link src to mandatory dst: \"${_entry}\"" \
     && false; \
    fi \
 && true "# 强制复位own和grp" \
 && if true; then true \
     && if [ -n "${_mandatory}" -a -n "${_own}" -a -n "${_src}" -a -z "${_dst}" ]; then true \
         && chown ${_own} `if [ -d ${_src} ]; then echo "${_src}/"; else echo "${_src}"; fi` \
         && true; \
        elif [ -n "${_mandatory}" -a -n "${_own}" -a -n "${_dst}" ]; then true \
         && chown ${_own} `if [ -d ${_dst} ]; then echo "${_dst}/"; else echo "${_dst}"; fi` \
         && true; \
        fi \
     && if [ -n "${_mandatory}" -a -n "${_grp}" -a -n "${_src}" -a -z "${_dst}" ]; then true \
         && chgrp ${_grp} `if [ -d ${_src} ]; then echo "${_src}/"; else echo "${_src}"; fi` \
         && true; \
        elif [ -n "${_mandatory}" -a -n "${_grp}" -a -n "${_dst}" ]; then true \
         && chgrp ${_grp} `if [ -d ${_dst} ]; then echo "${_dst}/"; else echo "${_dst}"; fi` \
         && true; \
        fi \
     && true; \
    fi \
 && true; \
}
function run_docker_registry() {
    true \
 && local REGISTRY_PORT=${1:-${REGISTRY_PORT:-5000}} \
 && local REGISTRY_NAME=${REGISTRY_NAME:-registry} \
 && local REGISTRY_DIR=${REGISTRY_DIR:-$HOME/.local/var/lib/registry} \
 && if [ ! -d ${REGISTRY_DIR} ]; then mkdir -p ${REGISTRY_DIR}; fi \
 && if ! docker ps --format={{.Names}} | grep -s -x "${REGISTRY_NAME}"; then true \
     && docker run -d \
            -e REGISTRY_HTTP_ADDR=0.0.0.0:${REGISTRY_PORT} \
            -p ${REGISTRY_PORT}:${REGISTRY_PORT} \
            --restart=always \
            --name ${REGISTRY_NAME} \
            -v ${REGISTRY_DIR}:/var/lib/registry \
            registry:2 \
     && true; \
    fi \
 && docker ps | grep -F "${REGISTRY_NAME}" \
 && true;
}
# end of feature functions
#-------------------------------------------------------------------------------
#---------------- cut here end iecha4aeXot7AecooNgai7Ezae3zoRi7 ----------------
function _pri_init_1_inline() {
    echo \
'
# 防止诸如: alias grep="grep -n"之类的改变grep默认输出行为的alias
unalias grep 2>/dev/null
# TODO: workaround OSX gnu expr replacement
if command -v gexpr >/dev/null; then
    G_expr_bin=gexpr
else
    G_expr_bin=expr
fi
# TODO: workaround OSX gnu base64 replacement
if command -v gbase64 >/dev/null; then
    base64=gbase64
else
    base64=base64
fi
# initialize fake log_XXX in case log.sh could not be loaded.
for item in error warn info debug
do
    p=`$G_expr_bin substr $item 1 1 | tr "[a-z]" "[A-Z]"`
    declare -F log_$item &>/dev/null || \
    eval "function log_$item { echo \"[$p]: \$@\" >&2; }"
done
declare -F log_lines &>/dev/null || \
eval "function log_lines { true; }"
'
}
function enc_self_b64_gz() {
    # 把以上功能函数（包含在{begin,end} of feature functions中间的代码）编码成自包含的代码
    local fself=$1
    if [ -n "$fself" -a -f "$fself" ]; then
        shift
    else
        fself=$0
    fi
    local tbeg=${1:-"Aeth4Aechoo7ca7aez4eesh3eigeitho"}
    local tend=${2:-"iecha4aeXot7AecooNgai7Ezae3zoRi7"}
    if [ -n "$fself" -a -f "$fself" ]; then
        local lines=`sed -e '1,/cut here beg '$tbeg'/d' -e '/cut here end '$tend'/,$d' $fself`
        if [ -n "$lines" ]; then
            echo \
'#! /usr/bin/env bash

PROG_CLI=${PROG_CLI:-`command -v $0`}
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}


[ "$DEBUG" = "true" ] && set -x
USER=${USER:-`id -u -n`}
hostname_s=`hostname -s`

'"`_pri_init_1_inline`"'
declare -F run_initialize_ops &>/dev/null || \
if ! eval "`(cat - <<EOF'
            echo "$lines" | gzip | base64 -w 80
            echo \
'EOF
) | $base64 -i -d | gzip -d`"; then
    log_error "Fail to import lib \"'${PROG_CLI}'\""
fi'
        else
            false
        fi
    else
        false
    fi
}


# ------------------------------------------------------------------------------
# begin of self run
#
# call as:
# 1) ./utils.sh    <-- self call
# 2) cat utils.sh | bash -    <-- inline call
if [ "$PROG_NAME" = "utils.sh" -o "$PROG_NAME" = "bash" ]; then
    eval "`_pri_init_1_inline`"
    #
    # loading log.sh
    #
    # NOTE: unset fake or legacy log_XX before tring to import real ones
    for item in error warn info debug lines; do unset log_$item; done && \
    # load the lib
    if ! eval "$(if [ ! -f "${PROG_DIR}/log.sh" -o "`type -t log.sh`" != "file" ]; then
        gen_lib_source_cmd log.sh https://github.com/dillonfzw/utils/raw/master/log.sh
    else
        echo "source ${PROG_DIR}/log.sh"
    fi)"; then
        echo "[E]: Fail to source \"log.sh\". Abort!" >&2
        exit 1
    fi && \
    #
    # loading getopt.sh
    #
    if ! eval "$(if [ ! -f "${PROG_DIR}/getopt.sh" -o "`type -t getopt.sh`" != "file" ]; then
        gen_lib_source_cmd getopt.sh https://github.com/dillonfzw/utils/raw/master/getopt.sh
    else
        echo "source ${PROG_DIR}/getopt.sh"
    fi)"; then
        log_error "Fail to source \"getopt.sh\". Abort!"
        exit 1
    fi && \

    # set global shell debug
    if [ "${DEBUG}" = "true" ]; then set -x; fi && \

    run_initialize_ops && \

    # default to "usage"
    if [ -z "$cmd" ]; then cmd=usage; fi && \

    # issue real cmd
    if declare -F $cmd >/dev/null 2>&1; then
        $cmd $@
        exit $?
    else
        echo "Unknown cmd \"$cmd\""
        false
    fi
fi
#
# end of self run
# ------------------------------------------------------------------------------
