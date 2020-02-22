#! /bin/bash

KERNEL="`uname -s`"

############################################################
# include user's bashrc
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

############################################################
# setup EDITOR if no default
if [ -z "$EDITOR" ]; then
    EDITOR=vi
fi
export EDITOR

############################################################
# Pick up a mostly valid locale, en_US.UTF-8, if current one is invalid.
# Background:
# - OSX default locale, UTF-8, is mostly invalid in Linux box,
#   change it to en_US.UTF-8 if detected.
DEFAULT_locale=`locale -a | grep -Eix "en_US.UTF-8|en_US.utf8" | head -n1`
if [ -z "$DEFAULT_locale" ]; then DEFAULT_locale=C; fi
for item in LC_ALL LC_CTYPE LANG
do
  val=`locale 2>/dev/null | grep "^${item}=" | cut -d= -f2 | sed -e 's/\"//g'`
  if [ -z "$val" -o -z "$(locale -a 2>/dev/null | grep -Fx "$val")" ] && \
     [ "$val" != "$DEFAULT_locale" ]; then
    eval "$item=$DEFAULT_locale"
    export $item

    echo "Change $item from \"$val\" to \""`eval "echo \\\$$item"`"\""
  fi
done
unset DEFAULT_locale item

############################################################
# HOMEBREW token from dillonfzw@gmail.com, if not configured
ftoken=~/.ssh/HOMEBREW_GITHUB_API_TOKEN.dillonfzw@github.com
if [ "$KERNEL" = "Darwin" -a \
     -z "$HOMEBREW_GITHUB_API_TOKEN" -a \
     -f $ftoken ]; then
  HOMEBREW_GITHUB_API_TOKEN=$(<$ftoken)
  export HOMEBREW_GITHUB_API_TOKEN
fi

############################################################
# append $HOME/bin if not configured
for item in $HOME/bin $HOME/.local/bin
do
  if [ -d "$item" ] && ! echo "$PATH" | tr ':' '\n' | grep -sqFx "$item"; then
    PATH=$PATH:$item

    echo "Append $item to PATH"
  fi
done
unset item
export PATH

############################################################
# configure CSCOPE_EDITOR for development
if [ -n "$TMUX" -a -z "$CSCOPE_EDITOR" ]; then
  CSCOPE_EDITOR=`command -v vitmux`
  export CSCOPE_EDITOR

  echo "Define CSCOPE_EDITOR to $CSCOPE_EDITOR"
fi

############################################################
# activate python virtualenv wrapper
# NOTE:
# - disable this procedure by setting "ACTIVATE_PYTHON_VIRTUALENV=no" in ~/.bashrc
if [ -z "$WORKON_HOME" ]; then
  WORKON_HOME=~/.virtualenvs
  export WORKON_HOME
fi
if [ "$ACTIVATE_PYTHON_VIRTUALENV" != "no" -a "`type -t lsvirtualenv`" != "function" ] && \
   command -v virtualenvwrapper.sh >/dev/null 2>&1; then
  source virtualenvwrapper.sh

  echo "Source virtualenvwrapper.sh with WORKON_HOME equals to $WORKON_HOME"
fi

############################################################
# attach any existing ssh-agent
# NOTE:
# - disable this procedure by setting "ATTACH_SSH_AGENT=no" in ~/.bashrc
if [ "$ATTACH_SSH_AGENT" != "no" ] && command -v attach_ssh-agent.sh >/dev/null 2>&1; then
    source attach_ssh-agent.sh
fi

############################################################
# reset bcompare trial data after 15 days later
if [ "$KERNEL" = "Darwin" ]; then
    fbcreg="$HOME/Library/Application Support/Beyond Compare/registry.dat"
    fstamp_cmd="stat -f \"%a\" \"$fbcreg\""

elif [ "$KERNEL" = "Linux" ]; then
    fbcreg="$HOME/.config/bcompare/registry.dat"
    fstamp_cmd="stat -c \"%Y\" \"$fbcreg\""
fi
if [ -n "$fbcreg" -a -f "$fbcreg" ]; then
    fstamp=`eval "$fstamp_cmd"`
    stamp_now=`date "+%s"`
    sdiff=`expr $stamp_now - $fstamp`
    unset fstamp stamp_now
    
    if [ $sdiff -gt $((15 * 24 * 3600)) ]; then
        echo "Reset BCompare trial data"
        ls -l "$fbcreg" | sed -e 's/^/>> /g'

        rm -f "$fbcreg"
    fi
    unset sdiff
fi
unset fbcreg fstamp_cmd

############################################################
# SCM tools
if ! command -v lscm >/dev/null 2>&1; then
    RTC_SCMTOOLS_HOME=${RTC_SCMTOOLS_HOME:-$HOME/bin/apps/RTC-scmTools}
    RPATH=jazz/scmtools/eclipse
    if [ -x $RTC_SCMTOOLS_HOME/$RPATH/lscm ]; then
        export PATH=$PATH:$RTC_SCMTOOLS_HOME/$RPATH
        export SCM_DAEMON_PATH="$RTC_SCMTOOLS_HOME/$RPATH/scm"
        export RTC_SCRIPT_BASE="$RTC_SCMTOOLS_HOME/$RPATH/scripts"
        #unset SCM_ALLOW_INSECURE
        export SHOW_DEPRECATED_HELP=1

        echo "Add RTC-scmTools to PATH as $RTC_SCMTOOLS_HOME/$RPATH"
    fi
fi
unset RPATH

############################################################
# Anaconda
PYVER=${PYVER:-`python --version 2>&1 | grep ^Python | awk '{print $2}' | cut -d. -f1`}
if declare -F conda >/dev/null 2>&1; then
    # cache "conda info -s" output since it's little bit heavy
    _CONDA_INFO_Chae4dok9e="`conda info -s`"
    _CONDA_PATH_Chae4dok9e="`echo "$_CONDA_INFO_Chae4dok9e" | grep ^sys.prefix | awk '{print $2}'`/bin/conda"
else
    _CONDA_PATH_Chae4dok9e=`command -v conda`
fi
if [ -n "$_CONDA_PATH_Chae4dok9e" ]; then
    _CONDA_PATH_Chae4dok9e=`dirname $_CONDA_PATH_Chae4dok9e`
    if [ -z "$_CONDA_INFO_Chae4dok9e" ]; then
        _CONDA_INFO_Chae4dok9e="`conda info -s`"
    fi
    _CONDA_VER_Chae4dok9e=`echo "$_CONDA_INFO_Chae4dok9e" | grep ^sys.version | awk '{print $2}' | cut -d. -f1`
    unset _CONDA_INFO_Chae4dok9e
    # clean unmatched conda from PATH, or if conda() exists while no condabin which new version of conda provides
    if [ \( "$_CONDA_VER_Chae4dok9e" != "$PYVER" \) -o \
         \( "`command -v conda`" = "conda" -a ! -d "$_CONDA_PATH_Chae4dok9e/../condabin" \) ]; then
        export PATH=`echo "$PATH" | tr ':' '\n' | grep -vF "$_CONDA_PATH_Chae4dok9e" | xargs | tr ' ' ':'`
        echo "Remove $_CONDA_PATH_Chae4dok9e from PATH"
        unset _CONDA_PATH_Chae4dok9e
    fi
    unset _CONDA_VER_Chae4dok9e
fi
if true || [ -z "$_CONDA_PATH_Chae4dok9e" ]; then
    for item in $HOME/anaconda${PYVER} /opt/anaconda${PYVER}
    do
        if [ -d $item ]; then
            #
            # use conda's official initializer
            #
            # >>> conda initialize >>>
            # !! Contents within this block are managed by 'conda init' !!
            __conda_setup="$(echo | ${item}/bin/conda 'shell.bash' 'hook' 2>/dev/null)"
            if [ $? -eq 0 ]; then
                echo "Eval $item/bin/conda shell.bash hook..."
                eval "$__conda_setup"
                if [ "$CONDA_DEFAULT_ENV" = "base" ]; then
                    conda deactivate
                fi
            else
                if [ -f "${item}/etc/profile.d/conda.sh" ]; then
                    echo "Source $item/etc/profile.d/conda.sh..."
                    . "${item}/etc/profile.d/conda.sh"
                else
                    echo "Append $item/bin to PATH"
                    export PATH="${item}/bin:$PATH"
                fi
            fi
            unset __conda_setup
            # <<< conda initialize <<<
            break
        fi
    done
    unset item
fi
unset _CONDA_PATH_Chae4dok9e
unset PYVER


############################################################
#
# BFG tool
#
# https://rtyley.github.io/bfg-repo-cleaner/
#
if ! command -v bfg >/dev/null 2>&1 && [ -x $HOME/bin/apps/bfg/bin/bfg ]; then
    export PATH=$PATH:$HOME/bin/apps/bfg/bin
fi


############################################################
# Post process which MUST be in the last of this profile
#
# - unique PATH likely env vars
for var in PATH PYTHONPATH
do
    eval "val_ib9Chae3=\$$var"
    val_ib9Chae3="`echo $val_ib9Chae3 | tr ':' '\n' | \
                  nl -s, | sort -t, -k2 -u | sort -t, -k1 -n | cut -d, -f2- | \
                  xargs | tr ' ' ':'`"
    eval "$var=\"$val_ib9Chae3\""
done
unset val_ib9Chae3
# - clean local variables when this profile was sourced.
unset KERNEL


############################################################
# iTerm2 shell integration
#
# https://iterm2.com/documentation-shell-integration.html
# >> curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash
# >> curl -L https://iterm2.com/shell_integration/bash -o ~/.iterm2_shell_integration.bash
test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"


############################################################
# Configure bash behavior
#
# - enforce vi mode
set -o vi
