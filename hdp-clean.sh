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

# clean up packages first.
# purge those installed package only. or, apt-get will fail w/o cleaning any packages.
pkgs=`dpkg -l \
  hdp-select \
  postgresql \
  postgresql-9.3 \
  ambari-agent \
  ambari-server \
2>/dev/null | \
grep ^ii | awk '{print $2}' | xargs`

[ -n "$pkgs" ] && \
env LC_ALL=en_US.UTF-8 apt-get purge -y $pkgs

# clean up users and groups which might be left after their packages had been cleaned up.
for item in spark livy hive zookeeper ams ambari-qa tez hdfs yarn hcat mapred slider hadoop
do
  id -u $item 2>/dev/null && sudo userdel -rf $item
  id -g $item 2>/dev/null && sudo groupdel $item
done
cd -

# clean up directories and files permanently which had been left after their packages had been cleaned up.
rm -rf \
  /var/*/{hadoop*,ambari*,postgresql*} && \
  /etc/{hadoop*,ambari*} && \
  /usr/lib/flume && \
  /hdsk*/*
