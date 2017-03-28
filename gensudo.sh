#! /usr/bin/env bash

USER=${USER:-`whoami`}

lines="Defaults:$USER !requiretty
$USER ALL=(ALL) NOPASSWD:ALL"

if [ "$USER" != "root" -a ! -f /etc/sudoers.d/$USER ]; then
    echo "$lines" | sudo tee /etc/sudoers.d/$USER
fi
