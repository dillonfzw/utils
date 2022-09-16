#! /usr/bin/env bash


if true; then true \
 && COREX_HOME_uy7rohTh=${COREX_HOME:-/usr/local/corex} \
 && declare -a _extra_bin_path_uy7rohTh=() \
 && declare -a _extra_lib_path_uy7rohTh=() \
 && if [ -d "${COREX_HOME_uy7rohTh}" ] && \
         ! echo $PATH | tr ':' '\n' | grep -xF $COREX_HOME_uy7rohTh/bin; then true \
     && _extra_bin_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/bin") \
     && _extra_lib_path_uy7rohTh+=("${COREX_HOME_uy7rohTh}/lib64") \
     && true; \
    fi \
 && COREX_CMAKE_HOME_uy7rohTh=`ls -1d {/usr/local,/opt}/cmake-*-corex* 2>/dev/null | sort -V -r | head -n1` \
 && if [ "x${COREX_CMAKE_HOME_uy7rohTh}" != "x" ] && \
         ! echo $PATH | tr ':' '\n' | grep -xF $COREX_CMAKE_HOME_uy7rohTh/bin; then true \
     && _extra_bin_path_uy7rohTh+=("${COREX_CMAKE_HOME_uy7rohTh}/bin") \
     && true; \
    fi \
 && export PATH=`echo "${_extra_bin_path_uy7rohTh[@]}" | tr ' ' ':'`${PATH:+:${PATH}} \
 && export LD_LIBRARY_PATH=`echo "${_extra_lib_path_uy7rohTh[@]}" | tr ' ' ':'`${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
 && unset _extra_bin_path_uy7rohTh \
 && unset _extra_lib_path_uy7rohTh \
 && unset COREX_HOME_uy7rohTh \
 && unset COREX_CMAKE_HOME_uy7rohTh \
 && true; \
fi
