#! /usr/bin/env bash


sed \
    -e "s/^FROM  *\(.*\)$/echo FROM \1/g" \
    -e "s/^ARG  *\(.*\)$/declare -gx \1/g" \
    -e "s/^USER  *\(.*\)$/echo USER \1/g" \
    -e "s/^ENV  *\(.*\)$/declare -gx \1/g" \
    -e "s/^RUN  *\(.*\)$/if \[ \$\? -ne 0 \]; then exit -1; fi \&\& \1/g" \
    -e "s/^CMD  *\(.*\)$/\1/g" \
    $1 \
| source /dev/stdin
