#! /bin/bash

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


# ------------------ cut here beg Aeth4Aechoo7ca7aez4eesh3eigeitho -------------
#-------------------------------------------------------------------------------
# Utility functions
#
function get_env() {
    eval "echo \$$1" 2>/dev/null
}
function declare_p() {
    declare -p $@
}
function declare_p_val() {
    local var c length pos
    local G_expr_bin=${G_expr_bin:-expr}
    for var;
    do
        c=`declare -p $var`
        length=`$G_expr_bin length "$c"`
        pos=`$G_expr_bin index "$c" =`
        $G_expr_bin substr "$c" $((pos+2)) $((length-pos-2))
    done
}
function __test_declare_p_val() {
    local err_cnt=0

    local a=1237
    local b=`declare_p_val a`
    [ $a -eq $b ] || { ((err_cnt+=1)); log_error "fail sub-test 1: `declare -p b`"; }

    local a="hello world"
    local b=`declare_p_val a`
    [ "$a" == "$b" ] || { ((err_cnt+=1)); log_error "fail sub-test 2: `declare -p b`"; }

    local a="$(</etc/hosts)"
    local b=`declare_p_val a`
    [ "$a" == "$b" ] || { ((err_cnt+=1)); log_error "fail sub-test 3: `declare -p b`"; }

    local -a a=(1 2)
    local -a b=`declare_p_val a`
    array_equal a[@] b[@] || { ((err_cnt+=1)); log_error "fail sub-test 4: `declare -p b`"; }

    local -a a=(1 2 "hello" 5.88 "$(</etc/hosts)")
    local -a b=`declare_p_val a`
    array_equal a[@] b[@] || { ((err_cnt+=1)); log_error "fail sub-test 5: `declare -p b`"; }

    test $err_cnt -eq 0
}
function upper() {
    tr '[a-z]' '[A-Z]'
}
function run_unit_test() {
    local -a _NC3v_all_unit_test_cases=(`declare -F | awk '{print $3}' | grep "^__test" | sed -e 's/^__//' | xargs`)

    local -a _NC3v_target_cases
    if [ "$1" = "@all" -o $# -eq 0 ]; then
        _NC3v_target_cases=(${_NC3v_all_unit_test_cases[@]})
    else
        _NC3v_target_cases=($@)
    fi

    local i f_case
    for i in ${!_NC3v_target_cases[@]}
    do
        f_case=${_NC3v_target_cases[$i]}
        log_debug "Test $((i+1))/${#_NC3v_target_cases[@]} \"$f_case\"..."
        if __$f_case; then
            log_info "Test $((i+1))/${#_NC3v_target_cases[@]} \"$f_case\"... succ"
        else
            log_error "Test $((i+1))/${#_NC3v_target_cases[@]} \"$f_case\"... fail"
        fi
    done
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
    not_ grep -sqx 'adfadfadsfasdfadfadsfasdf' /etc/hosts || { ((err_cnt+=1)); log_error "Fail not_ false"; }

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
    local -a a=(1 2 3)
    local -a b=(1 2 3)
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
    #
    # :param set_a:
    # :param set_b:
    # :return: an array with the format of "local -p"'s value syntax
    local -a _i4cF_set_a=("${!1}")
    local -a _i4cF_set_b=("${!2}")

    # log for debug
    #declare -p _i4cF_set_a | sed -e 's/^/[set_union] >> /g' | log_lines debug
    #declare -p _i4cF_set_b | sed -e 's/^/[set_union] >> /g' | log_lines debug

    local -a _i4cF_set_d=`set_difference _i4cF_set_a[@] _i4cF_set_b[@]`

    # log for debug
    #declare -p _i4cF_set_d | sed -e 's/^/[set_union] >> /g' | log_lines debug

    local i e
    for i in ${!_i4cF_set_d[@]}
    do
        e="${_i4cF_set_d[$i]}"
        _i4cF_set_b+=("$e")
    done
    declare_p_val _i4cF_set_b
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
}
function setup_os_flags() {
    if [ -f /etc/os-release ]; then
        setup_linux_os_flags
        is_osx=false

    elif command -v sw_vers >/dev/null; then
        setup_osx_os_flags
        is_linux=false
        is_rhel=false; if_ubuntu=false

    else
        log_error "Unsupported OS distribution. Abort!"
        exit 1
    fi
    declare -a os_flags=(
      "is_osx"
      "is_linux"
      "is_rhel"
      "is_ubuntu"
      "ARCH"
      "OS_ID"
      "OS_VER"
      "OS_DISTRO"
    )
    for_each_op --silent declare_p ${os_flags[@]} | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
}
function setup_osx_os_flags() {
    # $ sw_vers
    # ProductName:	Mac OS X
    # ProductVersion:	10.13.5
    # BuildVersion:	17F77
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
function print_title() {
    echo -e "\n"
    echo "+-----------------------------------------------------------"
    echo "| $@"
    echo "+-----------------------------------------------------------"
    echo -e "\n"
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

    local pkg_vmin=`echo -e "${pkg_verE}\n${pkg_verR}" | sort -V | grep -v "^$" | head -n1`
    local msg="name=\"$pkg_name\", verA=\"$pkg_verR\", op=\"$pkg_op\", verB=\"$pkg_verE\", vMin=\"$pkg_vmin\""

    if [ \( -z "$pkg_verE" -a -n "$pkg_verR" \) -o \
         \( -n "$pkg_verE" -a -n "$pkg_verR" -a \( \
             \( "${pkg_verE}"  = "${pkg_verR}" -a `expr "#$pkg_op" : "^#.*=$"` -gt 1 \) -o \
             \( "${pkg_verE}" != "${pkg_verR}" -a \( \
                 \( `expr "#$pkg_op" : "^#>.*$"` -gt 1 -a "${pkg_vmin}" = "${pkg_verE}" \) -o \
                 \( `expr "#$pkg_op" : "^#<.*$"` -gt 1 -a "${pkg_vmin}" = "${pkg_verR}" \) \
             \) \) \
         \) \) ]; then
        if ! $silent; then log_debug "${FUNCNAME[0]} succ: $msg"; fi
    else
        if ! $silent; then log_error "${FUNCNAME[0]} fail: $msg"; fi
        false
    fi
}
function for_each_op() {
    local _ignore_error=false
    if [ "$1" = "--ignore_error" ]; then _ignore_error=true; shift; fi
    local _silent=false
    if [ "$1" = "--silent" ]; then _silent=true; shift; fi
    local _fs="$IFS"
    if [ "$1" = "--fs" ]; then
        _fs=$2; shift 2
    elif [ `expr "#$1" : "^#--fs="` -eq 6 ]; then
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
    local i=0
    local line=""
    for line in ${op_data[@]}
    do
        IFS="$IFS_OLD"
        [ -n "$line" ] || continue
        if ! $_silent; then
            print_title "Run \"$op\" at round $((i+1)) of $lcnt with parameter \"$line\""
        fi | log_lines debug
        $op ${op_args[@]} $line || $_ignore_error || break
        ((i+=1))
    done
    test $i -ge $lcnt
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

    local i=0
    while [ $i -lt 2 ]; do
        # silent in first round
        if [ $i -eq 0 ]; then $verify_op >/dev/null 2>&1; else $verify_op; fi && break;
        if [ $i -eq 0 ]; then $do_op; fi
        $wait_op
        ((i+=1))
    done
    test $i -lt 2
}
# download by checking cache first
function download_by_cache() {
    # pick up command line argument "cache_home", if there is
    local default_cache_home=~/.cache/download && \
    local cache_home=${cache_home:-${default_cache_home}} && \
    if [ "$1" = "--cache_home" ]; then
        cache_home=$2
        shift 2
    elif [ `expr "#$1" : "#--cache_home="` -eq 13 ]; then
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
    elif [ `expr "#$1" : "#--dry-run="` -eq 10 ]; then
        dry_run="`echo "$1" | cut -d= -f2-`"
        shift
    fi && \

    # calculate target hash location in the cache
    local url=$1 && \
    if [ "${url:0:1}" = "/" ]; then url="file://$url"; fi && \

    local f=`echo "$url" | awk -F/ '{print $NF}'` && \
    if [ -z "$f" ]; then log_error "URL \"$url\" does not point to a file"; false; fi && \

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

        curl -SL $url -o $cache_dir/.$f.$tmpn
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
function filter_pkgs_groupby() {
    local default_grp=${1:-"10"}

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
    command -v conda >/dev/null || declare -f conda >/dev/null
}
# shadow conda command
function _shadow_cmd_conda() {
    if declare -f conda >/dev/null; then
        conda $@
    elif command -v conda >/dev/null; then
        source $@
    fi
}
# different pip version has different command line options
function setup_conda_flags() {
    local conda_profile=$conda_install_home/etc/profile.d/conda.sh
    if do_and_verify "has_conda" "source $conda_profile" 'true'; then
        G_conda_bin="`conda info -s | grep ^sys.prefix: | awk '{print $2}'`/bin/conda"
        G_conda_install_flags=("--yes" ${conda_install_flags_extra[@]})
    fi
    declare -a conda_flags=(`set | grep "^G_conda" | cut -d= -f1 | sort -u`)
    for_each_op --silent declare_p ${conda_flags[@]} | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
}
# different pip version has different command line options
function setup_pip_flags() {
    if $use_conda && has_conda; then
        local env_activated=false
        if [ "${CONDA_DEFAULT_ENV}" = "$conda_env_name" ]; then
            env_activated=true
        fi
        if $env_activated || _shadow_cmd_conda activate ${conda_env_name}; then
            G_pip_bin=`command -v pip`
            G_python_ver=`python --version 2>&1 | grep ^Python | awk '{print $2}'`
            $env_activated || _shadow_cmd_conda deactivate
        fi
    else
        G_pip_bin=`command -v pip`
        G_python_ver=`python --version 2>&1 | grep ^Python | awk '{print $2}'`
    fi
    G_python_ver_major=`echo "$G_python_ver" | cut -d. -f1`
    G_python_ver_minor=`echo "$G_python_ver" | cut -d. -f2`

    local pip=$G_pip_bin
    local pip_version=`$pip --version | awk '{print $2}' | head -n1`
    if [ -n "$pip_version" ] && version_cmp pip ">=" "$pip_version" "9.0.1"; then
        G_pip_install_flags=("--upgrade" "--upgrade-strategy" "only-if-needed")
        G_pip_list_flags=("--format freeze")
    else
        G_pip_install_flags=("--upgrade")
        G_pip_list_flags=()
    fi
    G_pip_install_flags+=(${pip_install_flags_extra[@]})
    declare -a pip_flags=(`set | grep "^G_pip" | cut -d= -f1 | sort -u`)
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
    $sudo ${sudo:+"-i"} bash -c 'rm -rf $HOME/.cache/pip'
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
    $sudo yum ${G_yum_flags[@]} install -y $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "python2-pip|python3-pip|python34-pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_deb() {
    local pkgs="$@"
    $sudo ${G_apt_bin} install ${G_apt_install_flags[@]} $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "python-pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_pip() {
    local pip=$G_pip_bin
    local pkgs="$@"
    if ! $sudo test -z "$PYTHONUSERBASE" -o -d "$PYTHONUSERBASE"; then
        $sudo mkdir -p $PYTHONUSERBASE
    fi && \
    $sudo ${sudo:+"-i"} env ${PYTHONUSERBASE:+"PYTHONUSERBASE=$PYTHONUSERBASE"} \
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
    $sudo $G_conda_bin install ${conda_env_name:+"-n"} ${conda_env_name} ${G_conda_install_flags[@]} $pkgs
}
function pkg_list_installed_yum() {
    local pkgs="$@"
    $sudo yum ${G_yum_flags[@]} list installed $pkgs
}
function pkg_list_installed_deb() {
    local pkgs="$@"
    local pkgs_m=`echo "$pkgs" | tr ' ' '\n' | sed -e 's/=.*$//g' | xargs`
    dpkg -l $pkgs_m
}
function pkg_list_installed_pip() {
    local pip=$G_pip_bin
    local pkgs="$@"
    local regex=`echo "$pkgs" | tr ' ' '\n' | \
                 sed -e 's/[<=>]=.*$//g' -e 's/[<>].*$//g' -e 's/^\(.*\)$/^\1==/g' | \
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
                 sed -e 's/[<=>]=.*$//g' -e 's/[<>].*$//g' -e 's/^\(.*\)$/^\1==/g' | \
                 xargs | tr ' ' '|'`
    local cnt=`echo "$pkgs" | wc -w`
    # we'd better to compare package name case insensitive.
    local lines=`${G_conda_bin} list ${conda_env_name:+"-n"} ${conda_env_name} | awk '{print $1"=="$2}' | \
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
    $sudo rpm -V ${pkgs[@]}
}
function pkg_verify_deb() {
    declare -a pkgs=($@)
    if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi

    declare -a pkgs_m=(`echo "${pkgs[@]}" | tr ' ' '\n' | sed -e 's/=.*$//g'`)
    local out_lines=`$sudo dpkg -V ${pkgs_m[@]} 2>&1`
    if [ -n "$out_lines" ]; then
        log_error "Fail to verify packages \"${pkgs[@]}\""
        echo "$out_lines" | sed -e 's/^/>> /g' | log_lines error
        false
    fi
}
function _cmp_op_pair() {
    local pkg_op_pair="$1"
    local pkg_op=(  `echo "$pkg_op_pair" | cut -d'|' -f1  -s`)
    local pkg_verE=(`echo "$pkg_op_pair" | cut -d'|' -f2- -s`)

    if [ -n "$pkg_verE" ]; then
        version_cmp "$pkg_name" "$pkg_op" "$pkg_verR" "$pkg_verE"
    elif [ ! -n "$pkg_verR" ]; then
        log_error "Missing pkg \"$pkg\""
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
        # TODO: only support one operator for now.
        local pkg_line=`echo "$pkg" | sed -e 's/\([<=>!]\)/|\1/'`
        local pkg_name=`echo "$pkg_line" | cut -d'|' -f1`
        declare -a pkg_op_pairs=(`echo "$pkg_line" | cut -d'|' -f2- | tr ',' '\n' | sed \
          -e 's/^\([<=>!]=\)\([^<=>].*\)$/\1|\2/g' \
          -e 's/^\([<>]\)\([^<=>].*\)$/\1|\2/g'`)

        # we'd better to compare pip package name case insensitive.
        local pkg_verR=`echo "$out_lines" | grep -i "^$pkg_name==" | sed -e 's/^.*==//g'`

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
            for_each_line_op '$item'_conda "`filter_pkgs_conda $@`"
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
    declare -f | grep "^[^ ].* () *$" | sed -e 's/ *() *$//g'
}
function pstree() {
    pids="$@"
    pids_old=""
    while [ "$pids" != "$pids_old" ];
    do
        [ -n "$pids" ] || break
        pids_old="$pids"
        pids=`ps --pid "$pids" --ppid "$pids" -o pid --no-headers | awk '{print $1}' | sort -u | xargs`
    done
    [ -n "$pids" ] && echo "$pids"
}
command -v usleep >/dev/null || \
function usleep() {
    local num=$1
    sleep `awk -vnum=$num 'END{print num / 1000000}' </dev/null`
}
declare -f usage >/dev/null || \
function usage() {
    echo "Usage $PROGNAME"
    listFunctions | grep -v "^_" | sed -e 's/^/[cmd] >> /g' | log_lines info
    exit 0
}
function run_initialize_ops() {
    for_each_op eval ${G_registered_initialize_op[@]}
}
#-------------------------------------------------------------------------------
# utility functions initialize op
function _initialize_op_ohth3foo3zaisi7Phohwieshi9cahzof() {
    # ignore this op if it has not been registered
    if ! echo "${G_registered_initialize_op[@]}" | grep -sq "${FUNCNAME[0]}"; then
        true; return
    fi && \

    # make sure the env's locale is correct!!!
    setup_locales && \

    # os flags is highest priority
    declare -g is_linux && \
    declare -g is_osx && \
    declare -g is_rhel && \
    declare -g is_ubuntu && \
    declare -g ARCH && \
    declare -g OS_ID && \
    declare -g OS_VER && \
    declare -g OS_DISTRO && \
    setup_os_flags && \
    declare -g G_expr_bin="expr" && \
    if $is_osx; then
        if expr --version 2>&1 | grep -sq GNU; then
            G_expr_bin=expr
        elif gexpr --version 2>&1 | grep -sq GNU; then
            G_expr_bin=gexpr
        else
            log_error "utils.sh needs gnu expr program, use brew to install"
            false; return
        fi
    fi && \

    declare -g DEFAULT_use_conda=${DEFAULT_use_conda:-true} && \
    declare -g DEFAULT_sudo=${DEFAULT_sudo:-""} && \

    #-------------------------------------------------------------------------------
    # Setup conda related global variables/envs
    declare -g G_conda_bin=${G_conda_bin:-`command -v conda`} && \
    declare -ag G_conda_install_flags=${G_conda_install_flags:-()} && \
    setup_conda_flags && \

    declare -ag G_apt_install_flags=${G_apt_install_flags:-()} && \
    setup_apt_flags && \

    #-------------------------------------------------------------------------------
    # Setup pip related global variables/envs
    declare -g G_pip_bin=${G_pip_bin:-`command -v pip`} && \
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
    print_title "Install Anaconda${python_ver_major} installer's dependency" | log_lines debug && \
    declare -a pkgs=() && \
    if ! $is_osx; then
        pkgs+=("bzip2")
        if do_and_verify "pkg_verify ${pkgs[@]}" "pkg_install ${pkgs[@]}" "true"; then
            pkg_list_installed ${pkgs[@]}
        else
            log_error "Fail to install anaconda installer's dependent pkgs \"`filter_pkgs ${pkgs[@]} | xargs`\""
            false
        fi
    fi && \

    print_title "Install Anaconda${python_ver_major}" | log_lines debug && \
    if do_and_verify \
        'eval bash -l -c "conda --version 2>&1 | grep -sq \"^conda '$conda_ver'\""' \
        'eval f=`download_by_cache $conda_installer_url` && $sudo bash $f -b -p $conda_install_home &&
              $sudo ln -s $conda_install_home/etc/profile.d/conda.sh /etc/profile.d/ &&
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
    local _ve_name
    if [ "$1" = "--name" ]; then
        _ve_name=$2; shift 2
    elif [ `expr "#$1" : "^#--name="` -eq 8 ]; then
        _ve_name="${1/--name=}"; shift
    else
        _ve_name=$conda_ve_name
    fi
    local extra_args=$@

    print_title "Install Anaconda${python_ver_major} environment \"${_ve_name}\"" | log_lines debug && \
    if do_and_verify \
        'eval ${G_conda_bin} env list | grep -sq "^${_ve_name} \+"' \
        'eval if ! ${_user}; then _prefix=${sudo:+"${sudo} -i"}; fi; ${_prefix}${G_conda_bin} create --name ${_ve_name} --yes ${G_conda_install_flags[@]} $extra_args pip' \
        'true'; then
        {
            ${G_conda_bin} env list | grep "^${_ve_name} *"
            ${G_conda_bin} list --name $_ve_name
        } | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to create conda environment \"$_ve_name\""
        false
    fi
}
DEFAULT_conda_install_home=${DEFAULT_conda_install_home:-"/opt/anaconda${python_ver_major}"}
DEFAULT_conda_env_name=${DEFAULT_conda_env_name:-"base"}
DEFAULT_conda_installer_url=${DEFAULT_conda_installer_url:-"https://mirrors.tuna.tsinghua.edu.cn/anaconda/archive/Anaconda3-5.1.0-Linux-x86_64.sh"}
#"https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh"

# end of feature functions
#-------------------------------------------------------------------------------
#---------------- cut here end iecha4aeXot7AecooNgai7Ezae3zoRi7 ----------------
function enc_self_b64_gz() {
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
               echo "$lines" | gzip | base64 -w 80
        else
            false
        fi
    else
        false
    fi
}
