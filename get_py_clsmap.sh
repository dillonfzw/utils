#! /bin/bash

PROGNAME=${0##*/}

TMPDIR=/tmp
infile=`mktemp $TMPDIR/$PROGNAME.tmp.$$`

git grep "^class .*):" | sed -e 's/:class */ /g' -e 's/(\(.*\)): *$/ \1/g' -e 's/, */,/g' | tr -s ' ' >$infile

top_classes=`awk 'NF < 3 { print $2; } $3 == "object" { print $2; }' $infile`

function get_subclasses() {
    typeset level=$1; shift
    typeset classes=$*

    for cls in $classes
    do
        [ $level -gt 0 ] && printf "%$((level<<2))s" "--> "
        awk -v cls=$cls '$2 == cls { print $2" ("$1")"; }' $infile

        sub_classes=`awk '($3 == "'$cls'") || ($3 ~ /^'$cls',/) || ($3 ~ /,'$cls'/) || ($3 ~ /,'$cls'$/) { print $2; }' $infile`
        get_subclasses $((level+1)) $sub_classes
    done
}
get_subclasses 0 $top_classes

rm -f $infile
