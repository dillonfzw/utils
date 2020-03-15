#! /usr/bin/env bash


source log.sh


DEFAULT_ignore_dot_git=true
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


# validate parameter
if [ -z "${r4host}" -a -z "${r2host}" ]; then
    log_error "\"r4host\" or \"r2host\" should and can only have one available"
    exit 1
fi


# convert the XXhome parameter
rlhome=`eval "ls -1d $rlhome" | sed -e 's,/*$,,'`
phome=`eval "ls -1d $phome" | sed -e "s,^$rlhome/,," -e 's,/*$,,'`
declare -p rlhome
declare -p rrhome
declare -p phome

# prepare the sync cli
declare -a rsync_args=()
rsync_args+=("-av")
#rsync_args+=("--relative")
rsync_args+=("--exclude=**/.git")
rsync_args+=("--exclude=**/__pycache__")
rsync_args+=("--exclude=**/.DS_Store")
if $dry_run; then
    rsync_args+=("--dry-run")
fi
rsync_args+=(${OTHER_ARGS})
if [ -n "${r2host}" ]; then
    rsync_args+=($phome/ ${r2host}:${rrhome}/$phome/)
else
    rsync_args+=(${r4host}:${rrhome}/${phome}/ ${phome}/)
fi

# issue the sync cli
if cd $rlhome; then
    rsync ${rsync_args[@]}
    rc=$?
    cd - >/dev/null
    (exit $rc)
else
    false
fi
