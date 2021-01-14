#! /usr/bin/env bash


PROG_CLI=${PROG_CLI:-`command -v $0`}
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}


source log.sh
USER=${USER:-`id -u -n`}


DEFAULT_no_dot_git=true
DEFAULT_no_cscope=true
# relative local home which should be the phome's parent
DEFAULT_rlhome="~${USER}"
# relative remote home which should be the phome's parent
DEFAULT_rrhome="~${USER}"
# physical(?) home to be synced
DEFAULT_phome=`pwd`
# remote "from" host
DEFAULT_r4host=""
# remote "to" host
DEFAULT_r2host=""
DEFAULT_dry_run=false


source getopt.sh
OTHER_ARGS=$@


#
# transfer/sync content between local and remotes
#
# :param rlhost:
# :param rrhost:
# :param phome:
# :param r2host:
# :param r4host:
# :param dry_run:
#
function transfer() {
    # validate parameter
    if [ -z "${r4host}" -a -z "${r2host}" ]; then
        log_error "\"r4host\" or \"r2host\" should and can only have one available"
        return 1
    fi
    
    # handle group r2host cmds
    if echo "$r2host" | grep -sq ","; then
        local err_cnt=0
        for _r2host in `echo $r2host | tr ',' '\n' | xargs`
        do
            r2host=$_r2host transfer || ((err_cnt+=1))
        done
        if [ $err_cnt -ne 0 ]; then return 1; else return 0; fi
    fi

    # convert the XXhome parameter
    local _rlhome=`eval "ls -1d $rlhome" | sed -e 's,/*$,,'`
    local _phome=`eval "ls -1d $phome" | sed -e "s,^$_rlhome/,," -e 's,/*$,,'`
    local _rrhome=${rrhome}
    local _r2host=${r2host}
    local _r4host=${r4host}

    declare -p _rlhome
    declare -p _rrhome
    declare -p _phome
    declare -p _r2host
    declare -p _r4host
    
    # prepare the sync cli
    local -a rsync_args=()
    rsync_args+=("-av")
    rsync_args+=("--compress")
    #rsync_args+=("--relative")
    if ${no_dot_git}; then
        rsync_args+=("--exclude=**/.git")
    fi
    rsync_args+=("--exclude=**/__pycache__")
    rsync_args+=("--exclude=**/.DS_Store")
    rsync_args+=("--exclude=**/.idea")
    if ${no_cscope}; then
        rsync_args+=("--exclude=**/cscope.*")
        rsync_args+=("--exclude=**/tags")
    fi
    if $dry_run; then
        rsync_args+=("--dry-run")
    fi
    rsync_args+=(${OTHER_ARGS})
    if [ -n "${_r2host}" ]; then
        rsync_args+=($_phome/ ${_r2host}:${_rrhome}/$_phome/)
    else
        rsync_args+=(${_r4host}:${_rrhome}/${_phome}/ ${_phome}/)
    fi
    
    # issue the sync cli
    if cd $_rlhome; then
        rsync ${rsync_args[@]}
        rc=$?
        cd - >/dev/null
        (exit $rc)
    else
        false
    fi
}

transfer
