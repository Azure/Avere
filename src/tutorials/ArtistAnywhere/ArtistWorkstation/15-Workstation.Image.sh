#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'CentOS-7')" ]; then
    yum -y install nfs-utils
elif [ "$(cat /etc/os-release | grep 'CentOS-8')" ]; then
    dnf -y install nfs-utils
fi

cd /usr/local/bin
