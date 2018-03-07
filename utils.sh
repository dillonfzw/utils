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
    # pick up command line argument "cache_home", if there is
    local cache_home=${cache_home} && \
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

    # dry-run to pick up hash location
    local dry_run=${dry_run:-false} && \
    if [ "$1" = "--dry-run" ]; then
        dry_run=true
        shift
    elif [ `expr match "$1" "--dry-run="` -eq 9 ]; then
        dry_run="`echo "$1" | cut -d= -f2-`"
        shift
    fi && \

    # calculate target hash location in the cache
    local url=$1 && \
    if [ "${url:0:1}" = "/" ]; then url="file://$url"; fi && \

    local f=`echo "$url" | awk -F/ '{print $NF}'` && \
    if [ -z "$f" ]; then log_error "URL \"$url\" does not point to a file"; false; fi && \

    local d=${url%/${f}} && \
    local fsum=`echo "$f" | sum -r` && fsum=${fsum:0:2} && \
    local dsum=`echo "$d" | sum -r` && dsum=${dsum:0:2} && \
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
# different pip version has different command line options
function setup_pip_flags() {
    if $use_conda && command -v conda >/dev/null 2>&1; then
        local env_activated=false
        if [ "${CONDA_DEFAULT_ENV}" = "$conda_env_name" ]; then
            env_activated=true
        fi
        if $env_activated || source activate ${conda_env_name}; then
            G_pip_bin=`command -v pip`
            G_python_ver=`python --version 2>&1 | grep ^Python | awk '{print $2}'`
            $env_activated || source deactivate
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
        G_pip_install_flags="--upgrade --upgrade-strategy only-if-needed"
        G_pip_list_flags="--format freeze"
    else
        G_pip_install_flags="--upgrade"
        G_pip_list_flags=""
    fi
    set | grep "^G_pip" | sort -t= -k1 | sed -e 's/^/['${FUNCNAME[0]}'] >> /g' | log_lines debug
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
    $sudo yum $G_yum_flags install -y $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "python2-pip|python3-pip|python34-pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_deb() {
    local pkgs="$@"
    $sudo $apt_get install $apt_get_install_options $pkgs
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
        $pip install ${PYTHONUSERBASE:+"--user"} $G_pip_install_flags $pkgs
    local rc=$?

    if echo "$pkgs" | grep -sq -Ew "pip"; then
        setup_pip_flags
    fi
    return $rc
}
function pkg_install_conda() {
    if ! $use_conda; then return; fi
    local pkgs="$@"
    $sudo $conda install ${conda_env_name:+"-n"} ${conda_env_name} $conda_install_options $pkgs
}
function pkg_list_installed_yum() {
    local pkgs="$@"
    $sudo yum $G_yum_flags list installed $pkgs
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
    local lines=`{ if [ -n "$PYTHONUSERBASE" ]; then
                       $sudo ${sudo:+"-i"} env PYTHONUSERBASE=$PYTHONUSERBASE \
                         $pip list --user $G_pip_list_flags;
                   fi; \
                   $sudo ${sudo:+"-i"} $pip list $G_pip_list_flags; \
                 } | \
                 sed -e 's/ *(\(.*\))$/==\1/g' | \
                 sort -u | \
                 grep -E "$regex"`
    local lcnt=`echo "$lines" | grep -v "^$" | wc -l`
    echo "$lines"
    test $lcnt -eq $cnt
}
function pkg_list_installed_conda() {
    if ! $use_conda; then return; fi
    local pkgs="$@"
    local regex=`echo "$pkgs" | tr ' ' '\n' | \
                 sed -e 's/[<=>]=.*$//g' -e 's/[<>].*$//g' -e 's/^\(.*\)$/^\1==/g' | \
                 xargs | tr ' ' '|'`
    local cnt=`echo "$pkgs" | wc -w`
    local lines=`$sudo ${sudo:+"-i"} $conda list ${conda_env_name:+"-n"} ${conda_env_name} | awk '{print $1"=="$2}' | \
                   sed -e 's/ *(\(.*\))$/==\1/g' | \
                   grep -E "$regex"`
    local lcnt=`echo "$lines" | grep -v "^$" | wc -l`
    echo "$lines"
    test $lcnt -eq $cnt
}
function pkg_verify_yum() {
    local pkgs="$@"
    $sudo rpm -V $pkgs
}
function pkg_verify_deb() {
    local pkgs="$@"
    local pkgs_m=`echo "$pkgs" | tr ' ' '\n' | sed -e 's/=.*$//g' | xargs`
    local out_lines=`$sudo dpkg -V $pkgs_m 2>&1`
    if [ -n "$out_lines" ]; then
        log_error "Fail to verify packages \"$pkgs\""
        echo "$out_lines" | sed -e 's/^/>> /g' | log_lines error
        false
    fi
}
function pkg_verify_pip() {
    local pkgs="$@"
    # pkg_verify_conda will reuse most of logic of this function
    # so, we pick the fake conda pkg list output as faked pip output
    local out_lines=${conda_out_lines:-"`pkg_list_installed_pip $pkgs`"}
    if [ -z "$out_lines" ]; then return 1; fi
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
        if [ -n "$pkg_verE" ]; then
            version_cmp "$pkg_name" "$pkg_op" "$pkg_verR" "$pkg_verE"
        else
            true
        fi || break

        ((i+=1))
    done
    if [ $i -ne $cnt ]; then log_error "i=$i, cnt=$cnt"; fi
    test $i -eq $cnt
}
function pkg_verify_conda() {
    if ! $use_conda; then return; fi
    local pkgs="$@"
    local conda_out_lines="`pkg_list_installed_conda $pkgs`"
    pkg_verify_pip $@
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
        for_each_line_op '$item'_yum "`filter_pkgs_yum $@`" && \
        if $use_conda; then
            for_each_line_op '$item'_conda "`filter_pkgs_conda $@`"
        fi && \
        for_each_line_op '$item'_pip "`filter_pkgs_pip $@`"
    elif $is_ubuntu; then
        for_each_line_op '$item'_deb "`filter_pkgs_deb $@`" && \
        if $use_conda; then
            for_each_line_op '$item'_conda "`filter_pkgs_conda $@`"
        fi && \
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
function listFunctions() {
    declare -f | grep "^[^ ].* () *$" | sed -e 's/ *() *$//g'
}
function usage() {
    echo "Usage $PROGNAME"
    listFunctions | sed -e 's/^/[cmd] >> /g' | log_lines info
    exit 0
}
#
# end of utility functions
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
               echo "$lines" | gzip | base64 -b 80
        else
            false
        fi
    else
        false
    fi
}
