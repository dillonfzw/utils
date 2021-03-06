#! /usr/bin/env bash


PROG_CLI=${PROG_CLI:-`command -v $0`}
PROG_NAME=${PROG_NAME:-${PROG_CLI##*/}}
PROG_DIR=${PROG_DIR:-${PROG_CLI%/*}}


DEFAULT_LOG_LEVEL=${LOG_LEVEL:-debug}
DEFAULT_cmd=${cmd:-validate_conda_pkgs_dir}


function usage() {
    echo "Usage: ${PROG_NAME} [options]"
    echo "Options:"
    echo "   *conda_pkgs_dir=<dir1>{,<dir2>       :被操作的目标目录"
}


source $PROG_DIR/log.sh
source $PROG_DIR/getopt.sh


if [ -z "$conda_pkgs_dir" ]; then
    conda_pkgs_dirs=(`conda config --show pkgs_dirs | grep "^ *-" | awk '{print $2}'`)
else
    conda_pkgs_dirs=(`echo "$conda_pkgs_dir" | tr ',' ' '`)
fi
declare -p conda_pkgs_dirs


#
# 验证并清除conda_pkgs_dirs中无效的内容
#
# input:
# - conda_pkgs_dir array
#
function validate_conda_pkgs_dir() {
    local conda_pkgs_dir=""
    local err_cnt=0

    for conda_pkgs_dir in ${conda_pkgs_dirs[@]}
    do
        log_info ""
        log_info "Process conda_pkgs_dir \"$conda_pkgs_dir\""
        log_info ""

        if [   -n "$conda_pkgs_dir" \
            -a -d "$conda_pkgs_dir" \
            -a -f "$conda_pkgs_dir/urls.txt" \
            -a -f "$conda_pkgs_dir/urls" \
        ]; then
            true;
        else
            continue;
        fi \
     && if cd $conda_pkgs_dir; then
            for FILE in `ls -1d *.bz2 2>/dev/null`; \
            do \
                if [ -f $FILE.SHA1SUM ]; then \
                    true; \
                else \
                    if bzip2 -t $FILE; then \
                        sha1sum -b $FILE | tee $FILE.SHA1SUM \
                     && true; \
                    else \
                        log_warn "Fail to verify $FILE" \
                     && rm -f $FILE \
                     && true; \
                    fi \
                 && true; \
                fi \
             && true;
                if [ $? -ne 0 ]; then ((err_cnt+=1)); break; fi;
            done \
         && test $err_cnt -eq 0 \
         && find . -maxdepth 1 -type d | while read FILE; \
            do \
                FILE=`basename $FILE`;
                if [ -z "$FILE" -o "$FILE" = "." -o "$FILE" = ".." ]; then continue; fi;
                if [ -f $FILE.tar.bz2 ]; then \
                    true; \
                else \
                    log_info "rm obsolete $FILE" \
                 && rm -rf $FILE \
                 && { rm -f $FILE.* 2>/dev/null || true; } \
                 && true;
                fi \
             && true;
                if [ $? -ne 0 ]; then ((err_cnt+=1)); break; fi;
            done \
         && true;
            cd - >/dev/null;
            test $err_cnt -eq 0;
        else
            log_error "Cannot enter pkgs_dir \"$pkgs_dir\""
            ((err_cnt+=1))
            break
        fi;
        true;
    done \
 && test $err_cnt -eq 0 \
 && true;
}


# issue real cmd
if declare -F $cmd >/dev/null 2>&1; then
    $cmd $@
    exit $?
else
    echo "Unknown cmd \"$cmd\""
    false
fi
