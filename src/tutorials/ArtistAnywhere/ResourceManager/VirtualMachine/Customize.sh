#!/bin/bash

set -ex

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y install nfs-utils
else # centOS7
    yum -y install nfs-utils
fi
