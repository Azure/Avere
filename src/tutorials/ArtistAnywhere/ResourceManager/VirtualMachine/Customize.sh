#!/bin/bash

set -ex

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y install nfs-utils
else # centOS7
    yum -y install nfs-utils
fi

if [ $teradiciLicenseKey != "" ]; then
    yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
    yum -y install epel-release
    yum -y install usb-vhci
    yum -y install pcoip-agent-graphics
    pcoip-register-host --registration-code=$teradiciLicenseKey
fi
