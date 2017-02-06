#! /usr/bin/env bash

TMPDIR=/tmp
OS=$(uname -s)
PREFIX='
>>>	'



if [[ -f cscope.proj ]]; then
	CallTreeFiles=`grep "^CallTreeFiles=" cscope.proj | cut -d= -f2- | tail -1`
	LastOpenFile=` grep "^LastOpenFile="  cscope.proj | cut -d= -f2- | tail -1`
	OpenFiles=`    grep "^OpenFiles="     cscope.proj | cut -d= -f2- | tail -1`
	QueryFiles=`   grep "^QueryFiles="    cscope.proj | cut -d= -f2- | tail -1`
	Bookmarks=`    grep "^Bookmarks="     cscope.proj | cut -d= -f2- | tail -1`
	Name=`         grep "^Name="          cscope.proj | cut -d= -f2- | tail -1`
fi

PRJ_NAME=${1:-$Name}
if [[ -z $PRJ_NAME ]]; then
	echo "Usage: $0 <Project_name>"
	exit 1
fi

get_src()
{
	CURPWD=`pwd`;
	TGTDIR=$1
	cd $1
	find . -type f \(    -name '*.[chlyCGHLs]' \
                          -o -name '*.Ch' \
                          -o -name '*.cu' \
                          -o -name '*.hpp' \
                          -o -name '*.cpp' \
                          -o -name '*.cc' \
                          -o -name '*.py' \
                          -o -name '*.java' \
                          -o -name '*.scala' \
                       \) -print | grep -v release_dir | grep -v /usr/lpp/ | cut -d/ -f2-
	cd $CURPWD
}

cscope_prog=$(type -P cscope)
[[ -z $cscope_prog ]] && cscope_prog=$HOME/bin/cscope
[[ -x $cscope_prog ]] || cscope_prog=/tools/bin/cscope

ctags_prog=$(type -P ctags)

if [[ ! -x $cscope_prog ]]; then
	echo "cscope program does not detected in the system!\n"
	exit 1;
fi

readlink_prog=$(type -P readlink)
[[ -z $readlink_prog ]] && [[ `uname -s` = "AIX" ]] && readlink_prog="cmd.aix readlink"
readlink_opt="-f"

diff_prog=$(type -P diff)
if [[ -n $diff_prog ]]; then
	$diff_prog --version >/dev/null 2>&1 || diff_prog=""
fi

if [[ -z $diff_prog ]] && [[ `uname -s` = "AIX" ]]; then
	diff_prog="cmd.aix diff"
fi

SRC_DIR=
# if [[ $# -eq 1 ]]; then
	SRC_DIR=.
# else
# 	SRC_DIR=$2
# fi
ORIG_SRC_DIR=$SRC_DIR

CFILE_OUT=cscope.files
CFILE1=$TMPDIR/cscope.files.1
CFILE2=$TMPDIR/cscope.files.2


########################################################
# prepare the directory list
#
typeset DIRs="$SRC_DIR"
if [[ ! -L $SRC_DIR/link ]]; then
	if [[ -n $TOPS ]] && [[ $($readlink_prog $readlink_opt $SRC_DIR) = $($readlink_prog $readlink_opt $(echo $TOPS | cut -d: -f1)/src/ll) ]]; then
		typeset myTOPS="$(echo $TOPS | cut -d: -f2-)"
		DIRs="$DIRs $(echo $myTOPS | tr ':' '\n' | sed -e "s/$/\/src\/ll /g" | xargs)"
	fi
	SRC_DIR=""

elif [[ -d $SRC_DIR/link ]]; then
	SRC_DIR="$SRC_DIR/link"
fi


########################################################
# prepare the directory list for non-sandbox environment
#
[[ -n $SRC_DIR ]] && while true
do
	if [[ -L $SRC_DIR ]] && [[ -n $($readlink_prog $readlink_opt $SRC_DIR) ]]; then
		DIRs="$DIRs $($readlink_prog $readlink_opt $SRC_DIR)"
		SRC_DIR="$SRC_DIR/link"
	else
		break
	fi

done

########################################################
# Generate file list for cscope.
#
rm -f $CFILE1 $CFILE_OUT
touch $CFILE1
for SRC_DIR in $DIRs
do
	echo "$PREFIX Processing \"$SRC_DIR\"..."

	get_src $SRC_DIR > $CFILE1.tmp
	if [[ -n $TOPS ]]; then
		typeset expInc_prefix=../../export/$CONTEXT/usr
		typeset expInc=$SRC_DIR/$expInc_prefix

		if [[ -d $expInc ]]; then
			get_src $expInc | sed -e "s#^#${expInc_prefix}/#" >> $CFILE1.tmp
		fi
	fi
	sort $CFILE1.tmp > $CFILE1.right
	rm -f $CFILE1.tmp

	$diff_prog -u $CFILE1 $CFILE1.right | \
	grep "^+" | grep -v "^++" | sed -e "s/^+ *//g" | tee $CFILE2 | \
	sed "s#^#$SRC_DIR/#" | grep -v " " >> $CFILE_OUT
#	sed "s#^\(.*\)\$#\"$SRC_DIR/\1\"#" | grep -v " " >> $CFILE_OUT

if [[ -n $DEBUG ]]; then
	wc -l $CFILE1 $CFILE2
	echo "\nCFILE1 = \"$CFILE1\""
	cat $CFILE1
	echo "\nCFILE1.right = \"$CFILE1.right\""
	cat $CFILE1.right
	echo "\nCFILE2 = \"$CFILE2\""
	cat $CFILE2
fi
	rm -f $CFILE1.right

	# append new files and sort
	cat  $CFILE1 >> $CFILE2
	sort $CFILE2 >  $CFILE1
	rm -f $CFILE2
done
rm -f $CFILE1


########################################################
# Build cscope DB.
#
#$cscope_prog -b -q -n
#$cscope_prog -b -q -k
$cscope_prog -b -q 
#$cscope_prog -b

#$ctags_prog -R --c++-kinds=+px --fields=+iaS --extra=+q
$ctags_prog -L $CFILE_OUT

########################################################
# Build kscope project file.
#
if [[ ${ORIG_SRC_DIR} == "." ]]; then
	ORIG_SRC_DIR=`pwd`
fi
(
cat << EOF
Version=2

[AutoCompletion]
Delay=500
Enabled=false
MaxEntries=100
MinChars=3

[Project]
AutoRebuildTime=10
FileTypes=*.c *.h *.C *.y *.l
InvIndex=true
Kernel=false
Name=${PRJ_NAME}
RootPath=${ORIG_SRC_DIR}

[Session]
CallTreeFiles=${CallTreeFiles}
LastOpenFile=${LastOpenFile}
OpenFiles=${OpenFiles}
QueryFiles=${QueryFiles}
Bookmarks=${Bookmarks}
EOF
) > cscope.proj
echo "Cscope is ready...invoke with cscope -d"
