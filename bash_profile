#! /bin/bash

# Pick up a mostly valid locale, en_US.UTF-8, if current one is invalid.
# Background:
# - OSX default locale, UTF-8, is mostly invalid in Linux box,
#   change it to en_US.UTF-8 if detected.
for item in LC_CTYPE LC_ALL
do
  val=`locale 2>/dev/null | grep "^${item}=" | cut -d= -f2 | sed -e 's/\"//g'`
  if ! locale -a 2>/dev/null | grep -sqFx "$val"; then
    eval "$item=en_US.UTF-8"
    export $item

    echo "Change $item from \"$val\" to \""`eval "echo \\\$$item"`"\""
  fi
done

# HOMEBREW token from dillonfzw@gmail.com, if not configured
ftoken=~/.ssh/HOMEBREW_GITHUB_API_TOKEN.dillonfzw@github.com
if [ "`uname -s`" = "Darwin" -a \
     -z "$HOMEBREW_GITHUB_API_TOKEN" -a \
     -f $ftoken ]; then
  HOMEBREW_GITHUB_API_TOKEN=$(<$ftoken)
  export HOMEBREW_GITHUB_API_TOKEN
fi

# append $HOME/bin if not configured
if ! echo "$PATH" | tr ':' '\n' | grep -sqFx "$HOME/bin"; then
  PATH=$PATH:$HOME/bin
  export PATH

  echo "Append $HOME/bin to PATH"
fi

# configure CSCOPE_EDITOR for development
if [ -z "$CSCOPE_EDITOR" ]; then
  CSCOPE_EDITOR=`command -v vitmux`
  export CSCOPE_EDITOR

  echo "Define CSCOPE_EDITOR to $CSCOPE_EDITOR"
fi

# activate python virtualenv wrapper
if [ -z "$WORKON_HOME" ]; then
  WORKON_HOME=~/.virtualenvs
  export WORKON_HOME
fi
if [ "`type -t lsvirtualenv`" != "function" ] && command -v virtualenvwrapper.sh >/dev/null 2>&1; then
  source virtualenvwrapper.sh

  echo "Source virtualenvwrapper.sh with WORKON_HOME equals to $WORKON_HOME"
fi
