#! /usr/bin/env bash

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

PROGCLI=$0
PROGNAME=${0##*/} 
PROGVERSION=0.2.0

###################################################
# Define and import required library and functions
usage() {
    echo "Usage: $PROGNAME [options]" >&2
    echo "Options:" >&2
    echo "    -h|--help                   show this output" >&2
    echo "    -v|--version                show version of this program" >&2
    echo "    -l|--log log_file_name      log output to specific file also, if not specified, generate automatically in pwd" >&2
    echo "    -s|--ds_size <num>{M|G|T}   size of data set, default 1G" >&2
    echo "    -b|--blk_size <blk_size>{M} size of data block, default 128M" >&2
    echo "       --mapMxMem <mem>{M}      max memory for mapper task, default 1G" >&2
    echo "       --redMxMem <mem>{M}      max memory for reducer task, default 2G" >&2
    echo "       --mapTsks <numTsks>      number of mapper tasks to run, needed by TeraGen" >&2
    echo "       --redTsks <numTsks>      number of reducer tasks to run, needed by TeraSort" >&2
    echo "    -p|--params <param_file>    xml file which contains common parameters, default pmr-site.xml in pwd" >&2
    echo >&2
    echo "    gen                         TeraGen to generate data set" >&2
    echo "    sort                        TeraSort to sort data set, this is default cmd" >&2
    echo "    validate                    TeraValidate to validate sort result" >&2
    echo "    clean                       clean TeraSort and TeraValidate output data" >&2
    echo "    clean_gen                   clean TeraGen output data" >&2
    echo "    ls                          show all output data which include TeraGen, TeraSort and TeraValidate" >&2
    echo >&2
    echo "Example:" >&2
    echo "1). Run a 10G TeraSort test which starts from a TeraGen and ends with a validation and cleanup." >&2
    echo "    $PROGNAME -s 10G -b 256M gen sort validate clean" >&2
    echo "2). Run a 10G TeraSort test on existing 10G input data /gpfs/terasort_10G" >&2
    echo "    $PROGNAME -s 10G -b 256M sort" >&2
    echo "3). Run a 10G TeraGen to generate 10G data for TeraSort" >&2
    echo "    $PROGNAME -s 10G -b 256M gen" >&2
    return 0
}

source ./terasort.util.sh

USER=${USER:-`whoami`}
DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-server"
DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xcompressedrefs"
#DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xcodecache4m"

DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xnoclassgc"
#DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xgcpolicy:optthruput"
#DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xgcthreads4"

#DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xjit:optLevel=hot"
#DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-Xjit:disableProfiling"
#DEFAULT_java_common_opts=${DEFAULT_java_common_opts}${DEFAULT_java_common_opts:+ }"-XlockReservation"

DEFAULT_hadoop=`command -v hadoop`
DEFAULT_yarn=`command -v yarn`
DEFAULT_hdfs=`command -v hdfs`

HDP_HOME=/usr/hdp/current
dfsTestHome=/user/$USER


#########################
# Parser the CLI options
ARGS_ORIG="$@"
SHORTOPTS="s:b:l:p:hv"
LONGOPTS="ds_size:,blk_size:,log:,mapMxMem:,redMxMem:,mapTsks:,redTsks:,params:,help,version"
ARGS=`getopt -s bash --options $SHORTOPTS --longoptions $LONGOPTS --name $PROGNAME -- $ARGS_ORIG`
eval set -- "$ARGS"
while true;
do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "$PROGVERSION"
            exit 0
            ;;
        -s|--ds_size)
            shift
            ds_size=$1
            ;;
        -b|--blk_size)
            shift
            blk_size=$1
            ;;
        -l|--log)
            shift
            errlog=$1
            ;;
           --mapMxMem)
            shift
            mapMxMem=$1
            ;;
           --redMxMem)
            shift
            redMxMem=$1
            ;;
           --mapTsks)
            shift
            mapTsks=$1
            ;;
           --redTsks)
            shift
            redTsks=$1
            ;;
        -p|--params)
            shift
            fparams=$1
            ;;
        --) 
            shift
            break 
            ;; 
        *) 
            echo "[$1]"
            shift 
            break 
            ;;
     esac
     shift
done


######################
# Parser the commands
opts="$*"
[ -z "$opts" ] && opts="sort"
lines=`echo "$opts" | tr ' ' '\n'`
if echo "$lines" | grep -sq "^gen$"; then run_gen=true; else run_gen=false; fi
if echo "$lines" | grep -sq "^sort$"; then run_sort=true; else run_sort=false; fi
if echo "$lines" | grep -sq "^validate$"; then run_validate=true; else run_validate=false; fi
if echo "$lines" | grep -sq "^clean$"; then run_clean=true; else run_clean=false; fi
if echo "$lines" | grep -sq "^clean_gen$"; then run_clean_gen=true; else run_clean_gen=false; fi
if echo "$lines" | grep -sq "^ls$"; then run_ls=true; else run_ls=false; fi

if ! echo "$lines" | grep -sq "^log="; then
  [ -z "$errlog" ] && errlog=$PROGNAME.pid_$$.`hostname -s`.`date +"%Y-%m-%d_%H:%M:%S"`.log
  rm -f ${errlog}
  touch ${errlog}
  exec $PROGCLI $ARGS_ORIG log=$errlog 2>&1 | tee $errlog

  exit 0
else
  errlog=`echo "$lines" | grep "^log=" | cut -d= -f2`
fi


##############################
# PUBLIC parameters to run
# this benchmark
parameters="ds_size blk_size mapMxMem redMxMem mapTsks redTsks fparams errlog"

# Collect environment information
INPUT_DIR="$dfsTestHome/terasort_$ds_size"
OUTPUT_DIR="${INPUT_DIR}-out"
REPORT_DIR="${INPUT_DIR}-rep"

# [ -z "$HADOOP_HOME" ] && HADOOP_HOME=/opt/ibm/biginsights/IHC
# if [ ! -d "$HADOOP_HOME" ]; then
#     echo "HADOOP_HOME $HADOOP_HOME does not exist. Abort!" >&2
#     exit 1
# fi
# hadoop=$HADOOP_HOME/bin/hadoop

hadoop=${DEFAULT_hadoop:-$HDP_HOME/hadoop-client/bin/hadoop}
yarn=${DEFAULT_yarn:-$HDP_HOME/hadoop-client/bin/yarn}
hdfs=${DEFAULT_hdfs:-$HDP_HOME/hadoop-client/bin/hdfs}

hadoop_version=`$hadoop version 2>/dev/null | awk '$1 == "Hadoop" { print $2; }'`
if ! echo "$hadoop_version" | grep -sq "[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]"; then
    echo "Invalid hadoop version \"$hadoop_version\". Abort!" >&2
    exit 1
fi

# [biadmin@js22n09-eth1 benchmark]$ egosh user logon -u Admin -x Admin
# Logged on successfully
#
# $ egosh client list -ll -c SSM_/MapReduceConsumer/MapReduce61
# "CLIENT_NAME","STATE","TTL","ALLOC","CONSUMER","RGROUP","RESOURCES","SLOTS","USED"
# "SSM_/MapReduceConsumer/MapReduce61","CONNECTED","10","38","/MapReduceConsumer/MapReduce61","ComputeHosts","3","15","15"
#
# [biadmin@js22n09-eth1 benchmark]$ egosh user logoff
# Logged off successfully
false && \
sym_slots=`egosh -V >/dev/null 2>&1 && egosh user logon -u Admin -x Admin >/dev/null 2>&1 && {
  cname=$(egosh client list -ll | grep "SSM_\/MapReduceConsumer\/" | cut -d, -f1 | sed -e 's/"//g')
  egosh client list -ll -c $cname | tail -n 1 | cut -d, -f8 | cut -d\" -f2
  egosh user logoff >/dev/null 2>&1
}`
if ! echo "$sym_slots" | grep -sq "^[0-9]\+"; then
    echo "Could not get valid Symphony slots!" >&2
#    exit 1
fi

false && \
gpfs_blk_size=`[ -x /usr/lpp/mmfs/bin/mmlsfs ] && sudo /usr/lpp/mmfs/bin/mmlsfs gpfs -B | grep -i "Block size" | sed -e 's/^.* \([[:digit:]]\+\) \+Block size (\(.*\)).*$/\1:\2/' | join_lines -t,`
if ! echo "$gpfs_blk_size" | grep -sq "^[0-9]\+"; then
    echo "Could not get block size of GPFS file system!" >&2
#    exit 1
fi

false && \
gpfs_replicas=`[ -x /usr/lpp/mmfs/bin/mmlsfs ] && sudo /usr/lpp/mmfs/bin/mmlsfs gpfs -r | awk '$1 == "-r" { print $2; }'`
if ! echo "$gpfs_replicas" | grep -sq "^[0-9]\+"; then
    echo "Could not get default GPFS data replicas!" >&2
#    exit 1
fi


# Set default value for application options
DEFAULT_ds_size=1G
DEFAULT_blk_size=128M
DEFAULT_mapMxMem=1G
DEFAULT_redMxMem=2G
DEFAULT_fparms=pmr-site.xml
[ -z "$ds_size" ] && ds_size=$DEFAULT_ds_size
[ -z "$blk_size" ] && blk_size=$DEFAULT_blk_size
[ -z "$mapMxMem" ] && mapMxMem=$DEFAULT_mapMxMem
[ -z "$redMxMem" ] && redMxMem=$DEFAULT_redMxMem
[ -z "$fparams" ] && fparams=$DEFAULT_fparms
if $run_gen && [ -z "$mapTsks" ]; then
    echo "Option --mapTsks is mandatory for TeraGen. Abort" >&2
    exit 1
fi
if $run_sort && [ -z "$redTsks" ]; then
    echo "Option --redTsks is mandatory for TeraSort. Abort" >&2
    exit 1
fi



##################################
# Tuning parameters
# --------------------------------
fparams_common=`ls -U $fparams.common $fparams 2>/dev/null | head -n1`
if [ -n "$fparams_common" -a -f "$fparams_common" ]; then
    params_common=`cat $fparams_common | format_xml_to_params`

else

    # From Symphony solution team, WenYan, ChenShun
    java_common_opts=${java_common_opts:-${DEFAULT_java_common_opts}}

    codec_name=org.apache.hadoop.io.compress.DefaultCodec
    #codec_name=org.apache.hadoop.io.compress.SnappyCodec
    #codec_name=org.apache.hadoop.io.compress.Lz4Codec
    #codec_name=com.ibm.biginsights.compress.CmxCodec

    params_common=""
    params_common+=" -Dmapred.compress.map.output=true"

    params_common+=" -Dmapred.output.compress=true"
    params_common+=" -Dmapred.output.compression.type=BLOCK"
    params_common+=" -Dmapred.output.compression.codec=${codec_name}"
    params_common+=" -Dmapred.map.output.compression.codec=${codec_name}"

    params_common+=" -Dmapreduce.job.intermediatedata.checksum=false"

    params_common+=" -Dmapred.map.child.log.level=WARN"
    params_common+=" -Dmapred.reduce.child.log.level=WARN"

    params_common+=" -Djava.net.preferIPv4Stack=true"

    #default is 1000m
    params_common+=" -Dmapreduce.map.java.opts=\""
    params_common+="$java_common_opts -Xmx`convertToUnit $mapMxMem`m\""

    params_common+=" -Dmapreduce.reduce.java.opts=\""
    params_common+="$java_common_opts -Xmx`convertToUnit $redMxMem`m\""
fi

echo "$params_common" | format_params_to_xml >$errlog.params.xml.common


####################################
# Internal variables and formulas
# which should not modify by script
# users
# ----------------------------------
# nlines - the number of lines to generate as input
#
parameters+=" : nlines HADOOP_HOME hadoop_version sym_slots gpfs_blk_size gpfs_replicas"
nlines=$(expr `convertToByte $ds_size` / 100)

echo "#########################"
echo "# Running parameters:"
echo "# -----------------------"
for KEY in $parameters
do
  if [[ $KEY = ":" ]]; then
    echo "-----------------------"
    continue
  fi
  VAL=$(eval "echo \"\$${KEY}\"")
  echo "$KEY=$VAL"
done \
| sed -e "s/^/# /g"

# /opt/ibm/biginsights/IHC/bin/hadoop jar \
#     /opt/ibm/biginsights/IHC/hadoop-mr1-examples-2.2.0.jar terasort
#         -Dmapred.reduce.tasks=4 -Ddfs.blocksize=536870912
#         -Dmapred.map.child.java.opts=-Xmx1024m
#         -Dmapred.reduce.child.java.opts=-Xmx2048m
#         -Dio.sort.mb=256 -Dio.sort.record.percent=0.17
#         /hdm-tera-input /hdm-tera-output
TERA_APP_JAR=$(for hf in `ls \
  $HADOOP_HOME/hadoop-*example*.jar \
  $HADOOP_HOME/share/hadoop/mapreduce/hadoop-*-examples-*.jar \
  $HDP_HOME/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar \
  $HDP_HOME/*/hadoop-mapreduce-examples.jar \
  2>/dev/null | sort -V`; do readlink -m $hf; done | head -n1)
if [ -z "$TERA_APP_JAR" -o ! -r "$TERA_APP_JAR" ]; then
    echo "hadoop-example.jar does not exist or unreadable. Abort!"
    exit 1
fi

if mrsh version >/dev/null 2>&1; then
    mrsh="time mrsh"
else
    mrsh="time $hadoop"
fi

tera_clean() {
    local indir="$*"
    local title="Cleanup job"
    local cmd=""

    if [ -x "$hdfs" ]; then
        cmd="$hdfs dfs -rm -r -skipTrash"
    elif echo "$hadoop_version" | grep -sq "^1\."; then
        cmd="$hadoop dfs -rmr"
    else
        cmd="$hadoop dfs -rm -r -skipTrash"
    fi
    if [ -n "$indir" ]; then
        cmd+=" $indir"
    else
        $run_clean_gen && cmd+=" $INPUT_DIR"
        cmd+=" $OUTPUT_DIR"
        cmd+=" $REPORT_DIR"
    fi
    runCmd title cmd
}
tera_gen() {
    local title="Teragen job $ds_size:$INPUT_DIR"
    local params=""
    local cmd

    params+=" -Dmapreduce.job.name=TeraGen_${ds_size}"
    params+=" -Ddfs.block.size=`convertToByte ${blk_size}`"
    params+=" -Dmapred.map.tasks=$mapTsks"

    fparams_gen=`ls -U $fparams.gen 2>/dev/null | head -n1`
    if [ -n "$fparams_gen" -a -f "$fparams_gen" ]; then
        params+=`cat $fparams_gen | format_xml_to_params`
    fi

    tera_clean $INPUT_DIR

    cmd="$yarn jar $TERA_APP_JAR"
    cmd+=" teragen"
    cmd+=" `echo "$params_common $params" | updateHadoopDeprecatedProperties_in_params | uniq_params`"
    cmd+=" $nlines $INPUT_DIR"
    runCmd title cmd
}
tera_sort() {
    local title="Terasort job $ds_size:$INPUT_DIR"
    local params=""
    local cmd

    tera_clean $OUTPUT_DIR

    params+=" -Dmapreduce.job.name=TeraSort_${ds_size}"
    params+=" -Dmapred.min.split.size=`convertToByte ${blk_size}`"
    params+=" -Dmapred.reduce.tasks=$redTsks"
    params+=" -Ddfs.replication=1"

    fparams_sort=`ls -U $fparams.sort 2>/dev/null | head -n1`
    if [ -n "$fparams_sort" -a -f "$fparams_sort" ]; then
        params+=`cat $fparams_sort | format_xml_to_params`

    else
        # default is 256
        params+=" -Dio.sort.mb=400"
        # default is 10
        params+=" -Dio.sort.factor=80"
        #params+=" -Dio.sort.record.factor=0.8"
        # default is 0.05
        params+=" -Dio.sort.record.percent=0.17"
        # default is 0.8
        #params+=" -Dio.sort.spill.percent=0.8"
    
        # default is 0.6
        params+=" -Dmapred.reduce.slowstart.completed.maps=0.6"
        #params+=" -Dmapred.reduce.slowstart.completed.maps=0.00"
    
    #    # Symphony related
    #    # default is socket
    #    #params+=" -Dpmr.io.enhancement=socket"
    #    #params+=" -Dpmr.io.enhancement=normal"
    #    params+=" -Dpmr.io.enhancement=fs"
    #    #params+=" -Dpmr.io.enhancement=fc"
    #
    #    #params+=" -Dpmr.ondemand.2nd.sort.mb=true"
    #    # params+=" -Dpmr.io.enhancement.buffer.size=64"
    #    # params+=" -Dpmr.io.enhancement.buffer.size=256"
    #    #params+=" -Dpmr.shuffle.pas=true"
    #    #params+=" -Dpmr.decrease.map.output=true"
    #    # params+=" -Dpmr.io.read.enhancement=true"
    #
    #    # unknown parameter?
    #    # params+=" -Dsort.compare.prefix.key=true"
    #
        # shuffle related
        params+=" -Dmapred.job.reduce.input.buffer.percent=0.96"
        params+=" -Dmapred.job.shuffle.merge.percent=0.96"
        params+=" -Dmapred.job.shuffle.input.buffer.percent=0.7"
    fi
    echo "$params" | format_params_to_xml > $errlog.params.xml.sort

    cmd="$hadoop dfs -rm -r -skipTrash $OUTPUT_DIR"
    runCmd title cmd

    cmd="$yarn jar $TERA_APP_JAR"
    cmd+=" terasort"
    cmd+=" `echo "$params_common $params" | updateHadoopDeprecatedProperties_in_params | uniq_params`"
    cmd+=" $INPUT_DIR $OUTPUT_DIR"
    runCmd title cmd
}
tera_validate() {
    local title="Teravalidate job $OUTPUTDIR:$REPORT_DIR"
    local params=""
    local cmd

    tera_clean $REPORT_DIR

    params=""
    params+=" -Dmapreduce.job.name=TeraValidate_${ds_size}"

    cmd="$hadoop dfs -rm -r -skipTrash $REPORT_DIR"
    $run_validate && runCmd title cmd

    cmd="$hadoop jar $TERA_APP_JAR"
    cmd+=" teravalidate"
    cmd+=" `echo "$params_common $params" | updateHadoopDeprecatedProperties_in_params | uniq_params`"
    cmd+=" $OUTPUT_DIR $REPORT_DIR"
    runCmd title cmd
}
tera_ls() {
    local title="List files job"
    local cmd

    cmd="$hdfs dfs -ls"
    cmd+=" $INPUT_DIR"
    cmd+=" $OUTPUT_DIR"
    cmd+=" $REPORT_DIR"
    runCmd title cmd
}

#!!!!!!!!!!!!!
# MAIN start
#!!!!!!!!!!!!!
$run_gen && \
  tera_gen

$run_sort && \
  tera_sort

$run_validate && \
  tera_validate

$run_ls && \
  tera_ls

{ $run_clean || $run_clean_gen; } && \
  tera_clean
