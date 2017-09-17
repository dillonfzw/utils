#! /bin/bash

# Copyright 2017 IBM Corp.
#
# All Rights Reserved.
#
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



function setup_locale() {
    # locale setting requried by caffe and caffeOnSpark mvn building.
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
        echo "$cmd" | $sudo tee -a /etc/profile
        eval "$cmd"

        echo "Change $item from \"$val\" to \""`eval "echo \\\$$item"`"\""
      fi
    done
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
         \( -n "$pkg_verE" -a \( \
             \( "${pkg_verE}"  = "${pkg_verR}" -a `expr match "$pkg_op" "^.*=$"` -gt 0 \) -o \
             \( "${pkg_verE}" != "${pkg_verR}" -a \( \
                 \( `expr match "$pkg_op" "^>.*$"` -gt 0 -a "${pkg_vmin}" = "${pkg_verE}" \) -o \
                 \( `expr match "$pkg_op" "^<.*$"` -gt 0 -a "${pkg_vmin}" = "${pkg_verR}" \) \
             \) \) \
         \) \) ]; then
        if ! $silent; then log_debug "${FUNCNAME[0]} succ: $msg"; fi
    else
        if ! $silent; then log_error "${FUNCNAME[0]} fail: $msg"; fi
        false
    fi
}
function for_each_line_op() {
    local silent=false
    if [ "$1" = "--silent" ]; then silent=true; shift; fi
    local op=$1; shift
    local lines="$@"

    [ -n "$lines" ] || return 0

    local lcnt=`echo "$lines" | wc -l`
    local i=0
    local IFS_OLD="$IFS"
    IFS=$'\n'
    local line=""
    for line in $lines
    do
        IFS="$IFS_OLD"
        [ -n "$line" ] || continue
        if ! $silent; then
            print_title "Run \"$op\" at round $((i+1)) of $lcnt with parameter \"$line\""
        fi | log_lines debug
        $op $line || break
        ((i+=1))
    done
    test $i -ge $lcnt
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
    local cache_home=${cache_home}
    if [ "$1" = "--cache_home" ]; then
        cache_home=$2
        shift 2
    elif [ `expr match "$1" "--cache_home="` -eq 12 ]; then
        cache_home="`echo "$1" | cut -d= -f2-`"
        shift
    elif [ -z "$cache_home" ]; then
        log_error "Variable \"cache_home\" should not be empty for function \"${FUNCNAME[0]}\""
        false
    fi && \

    local url=$1 && \
    if [ "${url:0:1}" = "/" ]; then url="file://$url"; fi && \

    local f=`echo "$url" | awk -F/ '{print $NF}'` && \
    if [ -z "$f" ]; then log_error "URL \"$url\" does not point to a file"; false; fi && \

    local d=${url%/${f}} && \
    local fsum=`echo "$f" | sum -r` && fsum=${fsum:0:2} && \
    local dsum=`echo "$d" | sum -r` && dsum=${dsum:0:2} && \
    local cache_dir=${cache_home}/$dsum/$fsum && \
    if [ ! -d $cache_dir ]; then mkdir -p $cache_dir; fi && \

    if [ ! -f $cache_dir/$f ]; then
        log_info "Download and cache url \"$url\""
        local tmpn=`mktemp -u XXXX`

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
    else
        log_debug "Cache hit for url \"$url\""
    fi && \

    if [ -f $cache_dir/$f ]; then
        echo "$cache_dir/$f"
    else
        false
    fi
}
function filter_pkgs_groupby() {
    local default_grp=${1:-"10"}

    # put to default group, "10", if entry has no group specified
    awk -v default_grp=$default_grp '!/^[[:digit:]]+:/ { print default_grp":"$0; next; } { print; }' | \
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
# different pip version has different command line options
function setup_pip_flags() {
    local pip_version=`pip --version | awk '{print $2}' | head -n1`
    if [ -n "$pip_version" ] && version_cmp pip ">=" "$pip_version" "9.0.1"; then
        G_pip_install_flags="--upgrade --upgrade-strategy only-if-needed"
        G_pip_list_flags="--format freeze"
    else
        G_pip_install_flags="--upgrade"
        G_pip_list_flags=""
    fi
    log_debug "${FUNCNAME[0]}: pip_install=\"$G_pip_install_flags\", pip_list=\"$G_pip_list_flags\""
}
# clean cache directory to make docker image efficient
function clean_pip_cache() {
    $sudo ${sudo:+"-i"} bash -c 'rm -rf $HOME/.cache/pip'
}
function filter_pkgs_yum() {
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "rpm:" and non prefix pkgs
    grep -Ev "^deb:|^pip:" | sed -e 's/^rpm://g' | \
    filter_pkgs_groupby 10
}
function filter_pkgs_deb() {
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "deb:" and non prefix pkgs
    grep -Ev "^rpm:|^pip" | sed -e 's/^deb://g' | \
    filter_pkgs_groupby 10
}
function filter_pkgs_pip() {
    echo "$@" | sed -e 's/#[^[:space:]]\+//g' -e 's/ \+/ /g' | tr ' ' '\n' | \
    # pick "pip:" prefix only pkgs
    awk '/^pip:/ { sub(/^pip:/,""); print; }' | \
    filter_pkgs_groupby 10
}
function pkg_install_yum() {
    local pkgs="$@"
    $sudo yum $G_yum_flags install -y $pkgs
}
function pkg_install_deb() {
    local pkgs="$@"
    $sudo $apt_get install $apt_get_install_options $pkgs
}
function pkg_install_pip() {
    local pkgs="$@"
    if ! $sudo test -z "$PYTHONUSERBASE" -o -d "$PYTHONUSERBASE"; then
        $sudo mkdir -p $PYTHONUSERBASE
    fi && \
    $sudo ${sudo:+"-i"} env ${PYTHONUSERBASE:+"PYTHONUSERBASE=$PYTHONUSERBASE"} \
        pip install ${PYTHONUSERBASE:+"--user"} $G_pip_install_flags $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_list_installed_yum() {
    local pkgs="$@"
    $sudo yum $G_yum_flags list installed $pkgs
}
function pkg_list_installed_deb() {
    local pkgs="$@"
    dpkg -l $pkgs
}
function pkg_list_installed_pip() {
    local pkgs="$@"
    local regex=`echo "$pkgs" | tr ' ' '\n' | \
                 sed -e 's/[<=>]=.*$//g' -e 's/[<>].*$//g' -e 's/^\(.*\)$/^\1==/g' | \
                 xargs | tr ' ' '|'`
    local cnt=`echo "$pkgs" | wc -w`
    local lines=`$sudo ${sudo:+"-i"} env ${PYTHONUSERBASE:+"PYTHONUSERBASE=$PYTHONUSERBASE"} \
                   pip list ${PYTHONUSERBASE:+"--user"} $G_pip_list_flags | \
                   sed -e 's/ *(\(.*\))$/==\1/g' | \
                   grep -E "$regex"`
    local lcnt=`echo "$lines" | wc -l`
    echo "$lines"
    test $lcnt -eq $cnt
}
function pkg_verify_yum() {
    local pkgs="$@"
    $sudo rpm -V $pkgs
}
function pkg_verify_deb() {
    local pkgs="$@"
    local out_lines=`$sudo dpkg -V $pkgs 2>&1`
    if [ -n "$out_lines" ]; then
        log_error "Fail to verify packages \"$pkgs\""
        echo "$out_lines" | sed -e 's/^/>> /g' | log_lines error
        false
    fi
}
function pkg_verify_pip() {
    local pkgs="$@"
    local out_lines="`pkg_list_installed_pip $pkgs`" || return 1
    #echo "$out_lines" | sed -e 's/^/>> [pip]: /g' | log_lines debug

    local cnt=`echo "$pkgs" | wc -w`
    local i=0
    local pkg=""
    for pkg in $pkgs
    do
        # separate the pkg_name, operator and target version
        # TODO: only support one operator for now.
        local pkg_line=`echo "$pkg" | sed \
          -e 's/^\(.*\)\([<=>!]=\)\([^<=>].*\)$/\1|\2|\3/g' \
          -e 's/^\(.*\)\([<>]\)\([^<=>].*\)$/\1|\2|\3/g'`
        local pkg_name=`echo "$pkg_line" | cut -d'|' -f1`
        local pkg_op=`  echo "$pkg_line" | cut -d'|' -f2  -s`
        local pkg_verE=`echo "$pkg_line" | cut -d'|' -f3- -s`
        local pkg_verR=`echo "$out_lines" | grep "^$pkg_name==" | sed -e 's/^.*==//g'`
        version_cmp "$pkg_name" "$pkg_op" "$pkg_verR" "$pkg_verE" || break

        ((i+=1))
    done
    test $i -eq $cnt
}
function filter_pkgs() {
    if $is_rhel; then
        filter_pkgs_yum $@
    elif $is_ubuntu; then
        filter_pkgs_deb $@
    fi
    filter_pkgs_pip $@
}
# meta functions
for item in pkg_install pkg_list_installed pkg_verify
do
    eval 'function '$item'() {
    if $is_rhel; then
        for_each_line_op '$item'_yum "`filter_pkgs_yum $@`" && \
        for_each_line_op '$item'_pip "`filter_pkgs_pip $@`"
    elif $is_ubuntu; then
        for_each_line_op '$item'_deb "`filter_pkgs_deb $@`" && \
        for_each_line_op '$item'_pip "`filter_pkgs_pip $@`"
    else
        false
    fi
}'
done
# anchor code for usage() helper
echo '
function pkg_install() { true; }
function pkg_list_installed() { true; }
function pkg_verify() { true; }
' >/dev/null
