#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'centos:8')" ]; then
    yum -y groups install 'Workstation'
else
    yum -y install 'https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm'
    yum -y install epel-release
    yum -y install usb-vhci
    yum -y groups install 'GNOME Desktop'
fi
yum -y install nfs-utils

storageDirectory='/mnt/tools'
mkdir -p $storageDirectory
mount -t nfs -o rw,hard,rsize=65536,wsize=65536,vers=3,tcp 10.0.194.4:/tools $storageDirectory
