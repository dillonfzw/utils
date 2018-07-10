#! /usr/bin/env bash

source log.sh

DEFAULT_workspace=$HOME/workspace
DEFAULT_direct=to
DEFAULT_project=""
#DEFAULT_flags="--dry-run"

source getopt.sh
if [ -z "$project" ]; then
    log_error "\$project should not be empty!"
    exit 1
fi

if [ "$direct" = "to" ]; then
    rsync -av --compress --progress --exclude **/.git --exclude **/tests/nose/log.* $flags \
        $workspace/darwin-{platform,core} iqubic@seulogin:workspace/$project/
    git_commits=`
    for repo in $workspace/darwin-{platform,core}
    do
        if cd $repo; then
            echo $(basename $repo)
            git log -n10 --graph --oneline
            cd - >/dev/null 2>&1
        fi
    done`
    echo "$git_commits" | ssh iqubic@seulogin "cat - > ~iqubic/workspace/$project/.git_commits"
elif [ "$direct" = "from" ]; then
    rsync -av --compress --progress --exclude **/.git --exclude **/tests/nose/log.* $flags \
        iqubic@seulogin:workspace/$project/darwin-{platform,core} $workspace/
fi

