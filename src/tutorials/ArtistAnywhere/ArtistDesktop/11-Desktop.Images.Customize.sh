#!/bin/bash

set -ex

yum -y install nfs-utils

if [ "$(cat /etc/os-release | grep 'centos:8')" ]; then
    yum -y groups install 'Workstation'
else
    yum -y groups install 'GNOME Desktop'
fi
