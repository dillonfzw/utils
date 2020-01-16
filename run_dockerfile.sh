#! /usr/bin/env bash


for DOCKER_FILE in $@
do
    echo "echo -e \"\n\nAppling Dockerfile \"$DOCKER_FILE\"...\n\" >&2"
    sed \
        -e "s/^FROM  *\(.*\)$/echo FROM \1/g" \
        -e "s/^LABEL *\(.*\)$/echo \1/g" \
        -e "s/^USER  *\(.*\)$/echo USER \1/g" \
        \
        -e "s/^ARG  *\([^ =]*\)[ =]*\(.*\)$/declare -gx \1=\2/g" \
        -e "s/^ENV  *\([^ =]*\)[ =]\(.*\)$/declare -gx \1=\2/g" \
        \
        -e "s/^RUN  *\(.*\)$/if \[ \$\? -ne 0 \]; then true || exit -1; fi \&\& \1/g" \
        \
        -e "s/^CMD  *\(.*\)$/\1/g" \
        $DOCKER_FILE </dev/null
done \
| source /dev/stdin
