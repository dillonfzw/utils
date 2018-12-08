#! /usr/bin/env bash



source log.sh


DEFAULT_commit=HEAD
DEFAULT_include_remotes=origin
DEFAULT_exclude_branches=master


source getopt.sh


#set -o verbose
#set -e
#set -o pipefail


declare branches=`git branch --merged $commit -a | grep -vE '^ *\* *| -> ' | awk '{print $1}'`
declare -a local_branches=(` echo "$branches" | grep -v "^remotes\/" | cut -d\/ -f2- | xargs`)
declare -a remote_branches=(`echo "$branches" | grep    "^remotes\/" | cut -d\/ -f2- | xargs`)
declare branch
declare idx
declare out_lines
declare _c_exclude_branches_lines=`echo "${exclude_branches}" | tr ' ' '\n'`
for idx in ${!local_branches[@]}
do
    branch=${local_branches[$idx]}
    if echo "$_c_exclude_branches_lines" | grep -sqFx "$branch"; then continue; fi
    log_info "Clean local merged branch \"$branch\"." && {
        out_lines=`git branch -d $branch 2>&1`
        test $? -eq 0 || \
        echo "$out_lines" | grep -sq "branch '$branch' not found"
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "$out_lines" | sed -e 's/^/>> /g' | log_lines warn
        fi
        (exit $rc)
    } && \
    unset local_branches[$idx]
done
declare remote
declare _c_include_remotes_lines=`echo "${include_remotes}" | tr ' ' '\n'`
for idx in ${!remote_branches[@]}
do
    item=${remote_branches[$idx]}
    remote=`echo $item | cut -d\/ -f1` && \
    if [ -n "$include_remotes" ] && ! echo "${_c_include_remotes_lines}" | grep -sqFx "$remote"; then continue; fi
    branch=`echo $item | cut -d\/ -f2` && \
    if echo "$_c_exclude_branches_lines" | grep -sqFx "$branch"; then continue; fi
    log_info "Clean merged remote branch \"$item\"." && {
        out_lines=`git push --delete $remote $branch 2>&1`
        test $? -eq 0 || \
        echo "$out_lines" | grep -sqE "remote ref does not exist|branch '$item' not found"
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "$out_lines" | sed -e 's/^/>> /g' | log_lines warn
        fi
        (exit $rc)
    } && \
    git branch -r -d $item && \
    unset remote_branches[$idx]
done
