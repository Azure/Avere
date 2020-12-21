#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'CentOS-7')" ]; then
    yum -y groups install 'GNOME Desktop'
    yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
    yum -y install epel-release
    yum -y install usb-vhci
    yum -y install pcoip-agent-graphics
elif [ "$(cat /etc/os-release | grep 'CentOS-8')" ]; then
    dnf -y groups install 'Workstation'
fi

cd /usr/local/bin
