#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'centos:7')" ]; then
    yum -y install epel-release
fi
yum -y install nfs-utils
yum -y install jq

mv /tmp/Manager.Machines.DataAccess.sh /usr/local/bin
echo '0 0 * * * root /usr/local/bin/Manager.Machines.DataAccess.sh' > /var/spool/cron/root

storageDirectory='/mnt/tools'
mkdir -p $storageDirectory
mount -t nfs -o rw,hard,rsize=65536,wsize=65536,vers=3,tcp 10.0.194.4:/tools $storageDirectory

storageDirectory='/mnt/scenes'
mkdir -p $storageDirectory
mount -t nfs -o rw,hard,rsize=65536,wsize=65536,vers=3,tcp 10.0.194.4:/scenes $storageDirectory
