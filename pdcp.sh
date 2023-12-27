#! /usr/bin/env bash


HOSTFILE="~/.share/f.lst.ckpt_mrg"
SRC_TARGETS="n[11-19,21-26,29-40,42-46,59-61]"
DST_TARGETS="n[62-65,70-73,75,78-80,82,84-87,89,91,93,95,97,99,102,104,106,109-115,117-118]"
#DSH_TARGETS="n[62-63]"


function _pair() {
    true \
 && true set -x \
 && local _idx \
 && local -a _dst=(`pdsh -R exec -f 1 -w ${2} -x ${1} echo | cut -d: -f1 | xargs`) \
 && local -a _src=(`pdsh -R exec -f 1 -w ${1} echo | cut -d: -f1 | head -n${#_dst[@]} | xargs`) \
 && local _fanout=${3:-${_fanout}} \
 && local _has_fanout \
 && if [ -n "${_fanout}" ]; then _has_fanout=true; else _has_fanout=false; fi \
 && _fanout=${_fanout:-9999} \
 && local _chunk=`expr ${#_dst[@]} \/ ${#_src[@]}` \
 && if [ ${_chunk} -gt ${_fanout} ]; then _chunk=${_fanout}; fi \
 && local _remains=0 \
 && if ${_has_fanout} && [ ${_chunk} -lt ${_fanout} ]; then _remains=$((${#_dst[@]} - (${#_src[@]} * _chunk))); fi \
 && true declare -p _remains \
 && local -A _pairs=() \
 && for _idx in ${!_src[@]}; do true \
     && local _jdx \
     && _pairs[${_src[${_idx}]}]=`for _jdx in $(seq 0 $((_chunk-1))); do echo ${_dst[$((_idx*_chunk+${_jdx}))]}; done | xargs | tr ' ' ','` \
     && true declare -p _pairs \
     && true; \
    done \
 && if [ ${_remains} -gt 0 ]; then local _succ_cnt=0 && for _idx in `seq 0 $((_remains-1))`; do true \
     && _pairs[${_src[${_idx}]}]=${_pairs[${_src[${_idx}]}]},${_dst[$((${#_src[@]}*_chunk+${_idx}))]} \
     && { ((_succ_cnt+=1)) || true; } \
     && true declare -p _pairs \
     && true; \
    done && test ${_succ_cnt} -eq ${_remains}; fi \
 && declare -p _pairs \
 && true; \
}
function _pair2() {
    true \
 && true set -x \
 && local _fanout=${3} \
 && if [ -z "${_fanout}" ]; then _pair $@; return $?; fi \
 && local -a _dst=(`pdsh -R exec -f 1 -w ${2} -x ${1} echo | cut -d: -f1 | xargs`) \
 && local -a _src=(`pdsh -R exec -f 1 -w ${1} echo | cut -d: -f1 | head -n${#_dst[@]} | xargs`) \
 && if [ $((${#_src[@]} * (_fanout+1))) -gt ${#_dst[@]} ]; then { ((_fanout+=1)) || true; } fi \
 && true declare -p _src _dst _fanout \
 && local -A _pair=`_pair ${1} ${2} ${_fanout} | grep "^declare" | tail -n1 | cut -d= -f2-` \
 && declare -p _pair \
 && local _s \
 && local _cnt=`for _s in ${!_pair[@]}; do echo ${_pair[${_s}]} | awk -F, '{print NF}'; done | xargs | tr ' ' '+' | bc -l` \
 && local _idx \
 && for _idx in `seq 0 $((_cnt-1))`; do true \
     && _src+=(${_dst[${_idx}]}) \
     && unset _dst[${_idx}] \
     && true declare -p _src _dst \
     && true echo "${#_src[@]} ${#_dst[@]}" \
     && true echo "----" \
     && true; \
    done \
 && if [ ${#_dst[@]} -gt 0 ]; then true \
     && ${FUNCNAME[0]} \
            `echo ${_src[@]} | tr ' ' ','` \
            `echo ${_dst[@]} | tr ' ' ','` \
            ${_fanout} \
     && true; \
    fi \
 && true; \
}
function pdsh_cp() {
    true \
 && local _src=$1 && shift \
 && local _dst=$1 && shift \
 && local -A _pair=`_pair ${_src} ${_dst} | grep "^declare" | tail -n1 | cut -d= -f2-` \
 && local _src=`echo ${!_pair[@]} | tr ' ' ','` \
 && time pdsh -f 9999 -w ${_src} 'true set -x \
     && '"`declare -p _pair`"' \
     && function work() { true \
         && true set -x \
         && local _src="%h" \
         && local _dst=${_pair[${_src}]} \
         && pdsh -f 9999 -w ${_dst} "hostname -s" \
         && time pdcp -f 9999 -w ${_dst} '$@' \
         && true; \
        } \
     && work \
     && true; \
    ' \
 && true; \
}
function pdsh_cp2() {
    true \
 && local _LINE \
 && local _src=$1 && shift \
 && local _dst=$1 && shift \
 && local _fanout=$1 && shift \
 && _pair2 ${_src} ${_dst} ${_fanout} | while read _LINE; do if true \
     && local -A _pair=`echo "${_LINE}" | grep "^declare" | tail -n1 | cut -d= -f2-` \
     && local _src=`echo ${!_pair[@]} | tr ' ' ','` \
     && time pdsh -f 9999 -w ${_src} 'true set -x \
         && '"`declare -p _pair`"' \
         && function work() { true \
             && true set -x \
             && local _src="%h" \
             && local _dst=${_pair[${_src}]} \
             && echo pdsh -f 9999 -w ${_dst} "hostname -s" \
             && echo time pdcp -f 9999 -w ${_dst} '$@' \
             && true; \
            } \
         && work \
         && true; \
        ' \
     && true; then true; else break; fi; \
    done \
 && true; \
}


${cmd:-pdsh_cp} $@
