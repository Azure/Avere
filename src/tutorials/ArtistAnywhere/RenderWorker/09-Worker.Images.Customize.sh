#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'centos:7')" ]; then
    yum -y install epel-release
fi
yum -y install nfs-utils

storageDirectory='/mnt/tools'
mkdir -p $storageDirectory
mount -t nfs -o rw,hard,rsize=65536,wsize=65536,vers=3,tcp 10.0.194.4:/tools $storageDirectory
