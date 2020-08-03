#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'centos:7')" ]; then
    yum -y install epel-release
fi
yum -y install nfs-utils
