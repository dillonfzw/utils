#! /usr/bin/env bash

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



# backup plan of download_by_cache in utils.sh
# chicken and egg
declare _iem7aedu4ughahFe_cache_home=${cache_home:-${DEFAULT_cache_home:-"$HOME/.cache/misc"}}
if ! declare -F download_by_cache >/dev/null; then
    function download_by_cache() {
	local log_info=`command -v log_info`
	[ -n "$log_info" ] || log_info=echo

        local url=$1
        local f=`basename $url`
        [ -d $_iem7aedu4ughahFe_cache_home ] || mkdir -p $_iem7aedu4ughahFe_cache_home

        if [ ! -f $_iem7aedu4ughahFe_cache_home/$f ]; then
            if cd $_iem7aedu4ughahFe_cache_home; then
                $log_info "Download and cache url \"$url\"" >&2

                curl -SL $url -O
                rc=$?
                cd - >/dev/null
                test $rc -eq 0
            fi
        fi
        if [ -f $_iem7aedu4ughahFe_cache_home/$f ]; then
            echo "$_iem7aedu4ughahFe_cache_home/$f"
        else
            false
        fi
    }
fi
declare _iem7aedu4ughahFe_furl=""
declare _iem7aedu4ughahFe_succ_cnt=0
for _iem7aedu4ughahFe_furl in ${preReqLibs[@]}
do
    declare _iem7aedu4ughahFe_fname=${_iem7aedu4ughahFe_furl##*/}
    declare _iem7aedu4ughahFe_fpath=$_iem7aedu4ughahFe_fname

    if ! command -v $_iem7aedu4ughahFe_fname >/dev/null; then
        # fix permission problem which required by real build.
        if ${FIX_PERM:-false} && [ -d $_iem7aedu4ughahFe_cache_home ]; then
            $sudo chown -R $_iem7aedu4ughahFe_cache_home
        fi && \
    
        _iem7aedu4ughahFe_fpath=`download_by_cache $_iem7aedu4ughahFe_furl`
    else
        _iem7aedu4ughahFe_fpath=$_iem7aedu4ughahFe_fname
    fi && \
    if source $_iem7aedu4ughahFe_fpath; then
        ((_iem7aedu4ughahFe_succ_cnt+=1))
    else
        log_error "Fail to load $_iem7aedu4ughahFe_furl from $_iem7aedu4ughahFe_fpath"
    fi
done
if [ $_iem7aedu4ughahFe_succ_cnt -ne ${#preReqLibs[@]} ]; then
    exit 1
fi
eval `declare | grep "^_iem7aedu4ughahFe_.*=" | cut -d= -f1 | sed -e 's/^/unset /g'`
