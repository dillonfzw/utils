#! /usr/bin/env bash


if true; then true \
 && declare -a _extra_bin_path_uy7rohTh=() \
 && declare -a _extra_lib_path_uy7rohTh=() \
 && declare -a _extra_inc_path_uy7rohTh=() \
 && for CUDA_HOME_uy7rohTh in ${CUDA_HOME} /usr/local/cuda "`ls -1d /usr/local/cuda-* 2>/dev/null | sort -V | tail -n1`"; \
    do true \
     && if [ -z "${CUDA_HOME_uy7rohTh}" -o ! -d "${CUDA_HOME_uy7rohTh}/" ]; then true \
         && continue; \
        else true \
         && _extra_bin_path_uy7rohTh+=("${CUDA_HOME_uy7rohTh}/bin") \
         && _extra_lib_path_uy7rohTh+=("`ls -1d ${CUDA_HOME_uy7rohTh}/lib{,64} 2>/dev/null | head -n1`") \
         && _extra_inc_path_uy7rohTh+=("${CUDA_HOME_uy7rohTh}/include") \
         && true; \
        fi \
     && break; \
    done \
 && PATH=`echo "${_extra_bin_path_uy7rohTh[@]}" | tr ' ' ':'`${PATH:+:${PATH}} \
 && PATH=`echo "${PATH}" | tr ':' '\n' | nl -nln -w1 -s'|' | sort -t'|' -k2,2 -u | sort -t'|' -k1 -n | cut -d'|' -f2 | tr '\n' ':' | sed -e 's/^:\(.*\):/\1/g'` \
 && LD_LIBRARY_PATH=`echo "${_extra_lib_path_uy7rohTh[@]}" | tr ' ' ':'`${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
 && LD_LIBRARY_PATH=`echo "${LD_LIBRARY_PATH}" | tr ':' '\n' | nl -nln -w1 -s'|' | sort -t'|' -k2,2 -u | sort -t'|' -k1 -n | cut -d'|' -f2 | tr '\n' ':' | sed -e 's/^:\(.*\):/\1/g'` \
 && C_PATH=`echo "${_extra_inc_path_uy7rohTh[@]}" | tr ' ' ':'`${C_PATH:+:${C_PATH}} \
 && C_PATH=`echo "${C_PATH}" | tr ':' '\n' | nl -nln -w1 -s'|' | sort -t'|' -k2,2 -u | sort -t'|' -k1 -n | cut -d'|' -f2 | tr '\n' ':' | sed -e 's/^:\(.*\):/\1/g'` \
 && export PATH \
 && export LD_LIBRARY_PATH \
 && export C_PATH \
 && unset _extra_bin_path_uy7rohTh \
 && unset _extra_lib_path_uy7rohTh \
 && unset _extra_inc_path_uy7rohTh \
 && unset CUDA_HOME_uy7rohTh \
 && true; \
fi
