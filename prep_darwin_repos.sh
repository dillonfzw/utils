#! /usr/bin/env bash



source log.sh
source utils.sh


DEFAULT_reference_rel_home=~/workspace/darwin_r2.2_cmcc
DEFAULT_target_rel_home=`pwd`
DEFAULT_shared_repo_home=~/workspace


source getopt.sh


if [ -n "$SOCKS_PROXY" ]; then
    export GIT_SSH_COMMAND="ssh -o ProxyCommand=\"connect -S ${SOCKS_PROXY}%h %p\""
fi


declare -a repos=(
    "darwin-dev/darwin-core.git"
    "darwin-dev/darwin-platform.git"
    "darwin-dev/darwin-dashboard.git"
    "darwin-dev/darwin-inference.git"
    "darwin-dev/data_extractor.git"
    "darwin-gui/data_extractor_gui.git"
)
for repo in ${repos[@]}
do
    repo_name=`basename $repo .git` && \
    if [ ! -d "${target_rel_home}" ]; then mkdir -p ${target_rel_home}; fi && \
    if [ ! -d ${target_rel_home}/${repo_name} ]; then
        print_title "Create repo ${repo_name}"
        git clone --reference ${reference_rel_home}/${repo_name} --dissociate ${shared_repo_home}/${repo_name}.git ${target_rel_home}/${repo_name} && \
        git -C ${target_rel_home}/${repo_name} remote rename origin shared && \
        true
    fi && \
    if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx upstream; then
        git -C ${target_rel_home}/${repo_name} remote add upstream git@gitlab.com:$repo
    fi && \
    if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx origin; then
        git -C ${target_rel_home}/${repo_name} remote add origin git@gitlab.com:dillonfzw/${repo_name}.git
    fi && \
    if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx ref_rel; then
        git -C ${target_rel_home}/${repo_name} remote add ref_rel ${reference_rel_home}/${repo_name}
    fi && \
    lines=`git -C ${target_rel_home}/${repo_name} remote -v 2>&1` && \
    echo "$lines" | log_lines info && \
    for upstream in ref_rel upstream origin
    do
        _info=`echo "$lines" | tr '\t' ' ' | tr -s ' ' | grep "${upstream} .*fetch"`
        print_title "Fetch ${_info}"
        git -C ${target_rel_home}/${repo_name} fetch $upstream
    done
done
