#! /bin/bash

# OSX default UTF-8 locale is mostly invalid in Linux box,
# change it to en_US.UTF-8 if detected.
if [ -z "$LC_CTYPE" -o "$LC_CTYPE" = "UTF-8" ]; then
  LC_CTYPE=en_US.UTF-8
  export LC_CTYPE

  echo "Set LC_CTYPE to $LC_CTYPE"
fi

if [ -z "$LC_ALL" -o "$LC_ALL" = "UTF-8" ]; then
  LC_ALL=en_US.UTF-8
  export LC_ALL

  echo "Set LC_ALL to $LC_ALL"
fi

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
