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


PROGCLI=`command -v $0`
PROGNAME=${PROGCLI##*/}
PROGDIR=${PROGCLI%/*}
PROGVERSION=1.0.1

ARCH=`uname -m`
OS=`uname -s`

if [ -z "$APP_STORE" ]; then APP_STORE=$PROGDIR/../apps; fi

for item in $APP_STORE/mosh-1.2.6{.$ARCH.$OS,$ARCH,}
do
  if [ -d $item ]; then APP_HOME=$item; break; fi
done

APP_CMD_NAME=`basename $0 .sh`
export LD_LIBRARY_PATH=/lib64:$APP_HOME/lib${LD_LIBRARY_PATH:+:}${LD_LIBRARY_PATH}

APP_CMD_BIN=`command -v $APP_CMD_NAME 2>/dev/null`
if [ $? -ne 0 ]; then
    APP_CMD_BIN=$APP_HOME/bin/$APP_CMD_NAME
fi
exec $APP_CMD_BIN $@
