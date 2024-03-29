#! /usr/bin/env bash


if declare -F dedup &>/dev/null; then
function dedup_uy7rohTh() {
    dedup $@
}
else
function dedup_uy7rohTh() {
    # deduplication: sort and unique while keeping order
    tr ':' '\n' | sed -e '/^ *$/d' | nl -nln -w1 -s'|' | sort -t'|' -k2,2 -u | sort -t'|' -k1 -n | cut -d'|' -f2 | tr '\n' ':' | tr -s ':' | sed -e 's/^:\(.*\):/\1/g' -e 's/:$//g'
}
fi
if true; then true \
 && declare -a _extra_bin_path_uy7rohTh=() \
 && declare -a _extra_lib_path_uy7rohTh=() \
 && declare -a _extra_inc_path_uy7rohTh=() \
 && for COREX_HOME_uy7rohTh in ${COREX_HOME} $HOME/workspace/sw_home /usr/local/corex `ls -1d /usr/local/corex-* 2>/dev/null | sort -V -r` /opt/sw_home; \
    do true \
     && if [ -z "${COREX_HOME_uy7rohTh}" -o ! -d "${COREX_HOME_uy7rohTh}/" ]; then true \
         && continue; \
        elif echo "${COREX_HOME_uy7rohTh}" | grep -sq "/sw_home[/]*$" && [ -x ${COREX_HOME_uy7rohTh}/local/bin/ixsmi ]; then true \
         && _extra_bin_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/local/bin") \
         && _extra_bin_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/local/cuda/bin") \
         && _extra_lib_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/local/lib64") \
         && _extra_lib_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/local/cuda/lib64") \
         && _extra_inc_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/local/cuda/include") \
         && true; \
        elif [ -x ${COREX_HOME_uy7rohTh}/bin/ixsmi ]; then true \
         && _extra_bin_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/bin") \
         && _extra_lib_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/lib64") \
         && _extra_inc_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/include") \
         && true; \
        fi \
     && true; \
    done \
 && COREX_CMAKE_HOME_uy7rohTh=`ls -1d {/usr/local,/opt}/cmake-*-corex* 2>/dev/null | sort -V -r | head -n1` \
 && if [ "x${COREX_CMAKE_HOME_uy7rohTh}" != "x" ]; then true \
     && _extra_bin_path_uy7rohTh+=("${COREX_CMAKE_HOME_uy7rohTh}/bin") \
     && true; \
    fi \
 && PATH=`echo "${_extra_bin_path_uy7rohTh[@]}" | tr ' ' ':'`${PATH:+:${PATH}} \
 && PATH=`echo "${PATH}" | dedup_uy7rohTh` \
 && LD_LIBRARY_PATH=`echo "${_extra_lib_path_uy7rohTh[@]}" | tr ' ' ':'`${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
 && LD_LIBRARY_PATH=`echo "${LD_LIBRARY_PATH}" | dedup_uy7rohTh` \
 && C_PATH=`echo "${_extra_inc_path_uy7rohTh[@]}" | tr ' ' ':'`${C_PATH:+:${C_PATH}} \
 && C_PATH=`echo "${C_PATH}" | dedup_uy7rohTh` \
 && export PATH \
 && export LD_LIBRARY_PATH \
 && export C_PATH \
 && unset _extra_bin_path_uy7rohTh \
 && unset _extra_lib_path_uy7rohTh \
 && unset _extra_inc_path_uy7rohTh \
 && unset COREX_HOME_uy7rohTh \
 && unset COREX_CMAKE_HOME_uy7rohTh \
 && true; \
fi
unset dedup_uy7rohTh
