#! /usr/bin/env bash



source log.sh
source utils.sh


DEFAULT_reference_rel_home=${reference_rel_home:-"$HOME/workspace/darwin_r2.2"}
DEFAULT_target_rel_home=${target_rel_home:-`pwd`}
DEFAULT_shared_repo_home=${shared_repo_home:-"$HOME/workspace"}


source getopt.sh


if [ -n "$SOCKS_PROXY" ]; then
    #export GIT_SSH_COMMAND="ssh -o ProxyCommand=\"connect -S ${SOCKS_PROXY} %h %p\""
    export GIT_SSH_COMMAND="ssh -o ProxyCommand=\"nc -x ${SOCKS_PROXY} %h %p\""
fi


declare -a repos=(`echo "$repos" | tr ',' ' '`)
# 显式要求包含的repo
if [ -f "${target_rel_home}/.include_repos" ]; then
    declare -a _include_repos=($(<${target_rel_home}/.include_repos))
    declare -a repos=`set_union repos[@] _include_repos[@]`
    unset _include_repos
fi
# 显式要求去除的repo
if [ -f "${target_rel_home}/.exclude_repos" ]; then
    declare -a _exclude_repos=($(<${target_rel_home}/.exclude_repos))
    declare -a repos=`set_difference repos[@] _exclude_repos[@]`
    unset _exclude_repos
fi
# 如果啥也没说，使用默认的
if [ ${#repos[@]} -eq 0 ]; then
    declare -a _include_repos=(
        "darwin-dev/darwin-core.git"
        "darwin-dev/darwin-platform.git"
        #"darwin-dev/darwin-dashboard.git"
        #"darwin-dev/darwin-inference.git"
        #"darwin-dev/data_extractor.git"
        #"darwin-gui/data_extractor_gui.git"
        #"darwin-dev/darwin-aiocr.git"
        #"darwin-admin/darwin-license.git"
    )
    declare -a repos=`set_union repos[@] _include_repos[@]`
fi
for repo in ${repos[@]}
do
    repo_name=`basename $repo .git` && \
    if [ ! -d "${target_rel_home}" ]; then mkdir -p ${target_rel_home}; fi && \
    if [ ! -d ${target_rel_home}/${repo_name} ]; then
        print_title "Create repo ${repo_name}"
        if [ -d "${reference_rel_home}/${repo_name}" ]; then
            declare -a ref_args=(
                "--reference ${reference_rel_home}/${repo_name}"
                "--dissociate"
            )
        else
            declare -a ref_args=()
        fi && \
        git clone ${ref_args[@]} ${shared_repo_home}/${repo_name}.git ${target_rel_home}/${repo_name} && \
        git -C ${target_rel_home}/${repo_name} remote rename origin shared && \
        true
    fi && \
    if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx upstream; then
        git -C ${target_rel_home}/${repo_name} remote add upstream git@gitlab.com:$repo
    fi && \
    if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx origin; then
        git -C ${target_rel_home}/${repo_name} remote add origin git@gitlab.com:dillonfzw/${repo_name}.git
    fi && \
    if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx ref_rel && [ -d "${reference_rel_home}/${repo_name}" ]; then
        git -C ${target_rel_home}/${repo_name} remote add ref_rel ${reference_rel_home}/${repo_name}
    fi && \
    lines=`git -C ${target_rel_home}/${repo_name} remote -v 2>&1` && \
    echo "$lines" | log_lines info && \
    for upstream in shared ref_rel upstream origin
    do
        if ! git -C ${target_rel_home}/${repo_name} remote | grep -sqx ${upstream}; then continue; fi && \
        _info=`echo "$lines" | tr '\t' ' ' | tr -s ' ' | grep "${upstream} .*fetch"` && \
        print_title "Fetch ${_info}" && \
        git -C ${target_rel_home}/${repo_name} fetch $upstream && \
        if [ "$upstream" = "upstream" ]; then true \
         && print_title "Share ${_info}" \
         && git -C ${target_rel_home}/${repo_name} push shared refs/remotes/$upstream/master:refs/remotes/$upstream/master \
         && true; \
        fi; \
    done
done
