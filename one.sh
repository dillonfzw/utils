#! /usr/bin/env bash

LOG_LEVEL=${LOG_LEVEL:-"info"}
source log.sh
source utils.sh

DEFAULT_cmd="usage"
DEFAULT_pathogen_url="https://tpo.pe/pathogen.vim"
DEFAULT_syntastic_repo="https://github.com/vim-syntastic/syntastic.git"
source getopt.sh

function install_syntastic() {
    local vim_autoload="$HOME/.vim/autoload" && \
    local vim_bundle="$HOME/.vim/bundle" && \

    for_each_op "mkdir -p" "$vim_autoload $vim_bundle" && \
    local f_pathogen=`basename $pathogen_url` && \
    print_title "Install Pathogen..." && \
    if do_and_verify \
        "test -f $vim_autoload/$f_pathogen" \
        'eval f=`download_by_cache $pathogen_url` && cp -f $f $vim_autoload/' \
        "true"; then
        ls -ld $vim_autoload/$f_pathogen | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to install $f_pathogen from $pathogen_url"
        false
    fi && \

    print_title "Install Syntastic..." && \
    local d_syntastic=`basename $syntastic_repo .git` && \
    if do_and_verify \
        "test -d $vim_bundle/$d_syntastic/.git" \
        "git clone $syntastic_repo $vim_bundle/$d_syntastic" \
        "true"; then
        (cd $vim_bundle/$d_syntastic && git log -n1;) | sed -e 's/^/>> /g' | log_lines debug
    else
        log_error "Fail to check out $d_syntastic to $vim_bundle"
        false
    fi
}

$cmd "$@"
