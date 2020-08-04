#!/bin/bash

set -ex

yum -y install nfs-utils

if [ "$(cat /etc/os-release | grep 'centos:8')" ]; then
    yum -y groups install 'Workstation'
else
    yum -y install 'https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm'
    yum -y install epel-release
    yum -y install usb-vhci
    yum -y groups install 'GNOME Desktop'
fi
