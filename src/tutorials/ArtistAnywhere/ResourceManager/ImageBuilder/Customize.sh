#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:7" /etc/os-release && centOS7=true || centOS7=false

if $centOS7; then
    yum -y install nfs-utils
else # CentOS8
    dnf -y install nfs-utils
fi
