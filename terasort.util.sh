#! /bin/bash

# IBM_PROLOG_BEGIN_TAG
# Copyright 2017 IBM Corp.
#
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#               ------------------------------------------
#               THIS SCRIPT PROVIDED AS IS WITHOUT SUPPORT
#               ------------------------------------------
# IBM_PROLOG_END_TAG

#############################
# Function declarabion and implementation
# START...
getEnv() {
  typeset key=$1
  eval "echo \"\$${key}\""
}
getEnvUnitTest() {
    local resultExp="$HOME"
    local result=`getEnv HOME`
    echo "getEnv result=[$result]"
    echo "getEnv expect=[$resultExp]"
    test "$result" == "$resultExp"
}
#########################
# Stop Watch
#
typeset _time_start
typeset _time_stop
convertHMS() {
  awk 'END { t='$1'; s=t%60; t/=60; m=t%60; t/=60; h=t%24; t/=24; d=t; printf "%dd:%dh:%dm:%ds\n", d, h, m, s; }' /dev/null
}
reset_counter() {
  _time_start=`date +%s`
}
get_counter_raw() {
  _time_stop=`date +%s`
  local time_diff_raw
  ((time_diff_raw=_time_stop - _time_start))
  echo "$time_diff_raw"
}
get_counter() {
  local time_diff_raw=`get_counter_raw`
  convertHMS $time_diff_raw
}
stopWatchUnitTest() {
  count=2
  echo "test stop watch 1st case: sleep $count"
  reset_counter
  sleep $count
  echo "counted `get_counter_raw` seconds"
  echo "counted `get_counter`"
}

#################################################
# Unit exchanger
#
convertToByte() {
  typeset varU=`echo "$1" | sed -e 's/^\(.*\)\([KkMmGgTtPp]\)[Bb]*$/\2/'`
  typeset varV=`echo "$1" | sed -e 's/^\(.*\)\([KkMmGgTtPp]\)[Bb]*$/\1/'`

  # assume K,M,G,T,P is storage unit which 1000 based, and
  # assume k,m,g,t,p is 1024 based.
  typeset is1024=`if echo "$varU" | grep -sq '[kmgtp]'; then echo true; else echo false; fi`
  typeset my_k_unit=""
  if $is1024; then my_k_unit=1024; else my_k_unit=1000; fi

  # normalize unit to simplify the subsequent operations.
  varU=`echo "$varU" | tr 'kmgtp' 'KMGTP'`

  if [[ $varU = "K" ]]; then
    varV=`echo "scale=0; $varV * $my_k_unit" | bc -l`

  elif [[ $varU = "M" ]]; then
    varV=`echo "scale=0; $varV * ($my_k_unit * $my_k_unit)" | bc -l`

  elif [[ $varU = "G" ]]; then
    varV=`echo "scale=0; $varV * ($my_k_unit * $my_k_unit * $my_k_unit)" | bc -l`

  elif [[ $varU = "T" ]]; then
    varV=`echo "scale=0; $varV * ($my_k_unit * $my_k_unit * $my_k_unit * $my_k_unit)" | bc -l`

  elif [[ $varU = "P" ]]; then
    varV=`echo "scale=0; $varV * ($my_k_unit * $my_k_unit * $my_k_unit * $my_k_unit * $my_k_unit)" | bc -l`
  fi
  echo ${varV} | cut -d. -f1
}
convertEnvToByte() {
  typeset varName=$1
  typeset varVal=$(convertToByte $(getEnv $varName))
  eval "${varName}=${varVal}"
}
convertToUnit() {
  typeset varU=`echo $1 | tr 'kmgtp' 'KMGTP'`
  typeset varV=`convertToByte $2`
  if [[ $varU = "K" ]]; then
    varV=`echo "scale=0; $varV / $k_unit" | bc -l`

  elif [[ $varU = "M" ]]; then
    varV=`echo "scale=0; $varV / ($k_unit * $k_unit)" | bc -l`

  elif [[ $varU = "G" ]]; then
    varV=`echo "scale=0; $varV / ($k_unit * $k_unit * $k_unit)" | bc -l`

  elif [[ $varU = "T" ]]; then
    varV=`echo "scale=0; $varV / ($k_unit * $k_unit * $k_unit * $k_unit)" | bc -l`

  elif [[ $varU = "P" ]]; then
    varV=`echo "scale=0; $varV / ($k_unit * $k_unit * $k_unit * $k_unit * $k_unit)" | bc -l`
  fi
  echo ${varV} | cut -d. -f1
}
unitExchangerUnitTest() {
  for val in 1.5G 1M 1T 2g
  do
    typeset testVar=$val
    echo "bef testVar=$testVar"
    echo "mid tesetVar=`convertToUnit M $testVar`m"
    convertEnvToByte testVar
    echo "aft testVar=$testVar"
  done
}

############################
# run command with output
#
runCmd() {
  typeset __title=`getEnv $1`
  typeset __cmd=`getEnv $2`

  echo "$__cmd" | sed -e "s/ -D/ \\\\\n\t-D/g"

  typeset __rc;
  reset_counter
  eval "$__cmd"; __rc=$?
  echo "Return code of \"$__title\" is $__rc, time is `get_counter`" >&2
  return $__rc
}
###################################
# Safe xargs
#
join_lines() {
    local fs
    while getopts "t:" opt;
    do
        case $opt in
            t) fs="$OPTARG";;
        esac
    done
    shift $(($OPTIND - 1))
    [ -z "$fs" ] && fs=" "

    awk -v fs="$fs" '{ if (NR>1) printf("%s",fs); printf("%s",$0); } END{ printf("\n"); }'
}
join_linesUnitTest() {
    cat /etc/hosts | join_lines -t"|"
}
###################################
# my assumption to sort -u
#
uniq_per_key() {
    local fs
    local keyno
    local opt
    while getopts "t:k:" opt;
    do
        case $opt in
            t) fs="$OPTARG";;
            k) keyno="$OPTARG";;
        esac
    done
    shift $(($OPTIND - 1))

    [ -z "$fs" ] && fs=" "
    [ -z "$keyno" ] && keyno=0

    awk -F"$fs" -v keyno="$keyno" '(!($keyno in a)) { a[$keyno]=$0; print $0; }'
}
uniq_per_keyUnitTest() {
    local resultExp="a,2;b,1;c,3"
    local result=`echo "a,2;b,1;a,1;c,3" | tr ';' '\n' | uniq_per_key -t, -k1 | join_lines | tr ' ' ';'`
    echo "result=[$result]"
    echo "expect=[$resultExp]"
    test "$result" == "$resultExp"
}
##################################
# Java -D parameter uniq
uniq_params() {
    sed -e 's/[[:blank:]]*-D/\n/g' | grep ".\+=" \
    | uniq_per_key -t= -k1 \
    | sed -e 's/^/-D/' \
    | join_lines
}
uniq_paramsUnitTest() {
    local resultExp="-Da=1 -Db=2"
    local result=`echo "-Da=1 -Db=2 -Da=2" | uniq_params`
    echo "result=[$result]"
    echo "expect=[$resultExp]"
    test "$result" == "$resultExp"
}
############################################
# Convert hadoop parameter from 1.x to 2.x
updateHadoopDeprecatedProperties_in_params() {
    local target_ver=$hadoop_version
    if echo "$1" | grep -sq "^--target_version[= ]\+"; then
        target_ver=`echo "$1" | sed -e 's/^.*target_version[= ]\+//'`
    fi
    sed -e 's/[[:blank:]]*-D/\n/g' | grep ".\+=" \
    | sort -t= -k1 \
    | awk -v tbl=hadoopDeprecatedProperties.tbl -v hadoop_version=$target_ver '
    BEGIN {
        if (hadoop_version ~ /^2[.]/) {
            while ((getline line < tbl) > 0) {
                if (line ~ /^[[:blank:]]*#/) { continue; };

                split(line,a," ");
                pOld=a[1]; pNew=a[2];

                map[pOld]=pNew;

                # print "map["pOld"]=\""map[pOld]"\"";
            };
            close(tbl);
        }
    }
    {
        line=$0;
        pos=index(line,"=");
        if (pos == 0) {
            print line;
        } else {
            key=substr(line,1,pos-1);

            if (key in map) {
                print "[D]: map \""key"\" to \""map[key]"\"." > "/dev/stderr";
                key=map[key];
            };

            val=substr(line,pos+1);
            sub(/^\"*/,"",val);
            sub(/\"*$/,"",val);

            #print " -D"key"=\\\""val"\\\""
            print " -D"key"=\""val"\""
        }
    }' \
    | join_lines
}
updateHadoopDeprecatedProperties_in_paramsUnitTest() {
    local params="-Da=b"
    echo "$params" | updateHadoopDeprecatedProperties_in_params --target_version=4.5
    return $?
}
##############################################################
# Convert hadoop parameters from XML format to CLI for restore
format_xml_to_params() {
    xmllint --path '//configuration/property' -noblanks - \
    | sed -ne '/<!--/ { :c; /-->/! { N; b c; }; /-->/s/<!--.*-->//g }; /^  *$/!p;' \
    | sed -e 's/></>\n</g' \
    | awk -F'[<>]' '
      $2=="name" { name=$3; }
      $2=="value" {
        gsub(/^[[:blank:]]*/,"",$3);
        gsub(/[[:blank:]]*$/,"",$3);
        #print "-D"name"=\\\""$3"\\\"";
        print "-D"name"=\""$3"\"";
      }' \
    | join_lines \
    | updateHadoopDeprecatedProperties_in_params
}
#########################################################
# format hadoop parameter from CLI format to xml for save
format_params_to_xml() {
    updateHadoopDeprecatedProperties_in_params \
    | sed -e 's/[[:blank:]]*-D/\n/g' | grep ".\+=" \
    | awk -F= '
    BEGIN {
        print "<?xml version=\"1.0\"?>";
        print "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>";
        print "<configuration>";
    }
    ($0 ~ /.+=/) && ($2 !~ /^\"* *\"*$/) {
        line=$0;
        sub(/=\"* */,"</name><value>",line);
        sub(/ *\"*$/,"",line);
        print "<property><name>"line"</value></property>"
    }
    END { print "</configuration>"; }
    ' \
    | xmllint --format -
}

#############################
# Unit test main
unitTestMain() {
  typeset rc=0
  for item in $utTarget
  do
    {
    eval "${item}UnitTest";
    rc=$?
    echo "rc=$rc"
    } | sed -e "s/^/${item}UnitTest: /"
    [[ $rc -ne 0 ]] && break;
  done 2>&1 | sed -e "s/^/>> /"
  return $rc
}

# UT for internal functions
# comment out any test item to enable test.
# use grep "UnitTest(" to find out testable functions.
utTarget=""
utTarget+=" getEnv"
utTarget+=" stopWatch"
utTarget+=" unitExchanger"
utTarget+=" join_lines"
utTarget+=" uniq_per_key"
utTarget+=" uniq_params"
if [ "x$UNIT_TEST" = "xtrue" ]; then
    unitTestMain
fi
