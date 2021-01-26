#!/bin/bash

set -ex

grep 'centos:7' /etc/os-release && centOS7=true || centOS7=false

if $centOS7; then
    yum -y update
    yum -y install gcc
    yum -y install kernel-devel
    yum -y install nfs-utils
else # CentOS8
    dnf -y update
    dnf -y install gcc
    dnf -y install kernel-devel
    dnf -y install nfs-utils
fi

echo "blacklist nouveau" > /etc/modprobe.d/nouveau.conf
echo "blacklist lbm-nouveau" >> /etc/modprobe.d/nouveau.conf

#systemctl reboot

cd /usr/local/bin

downloadUrl='https://usawest.blob.core.windows.net/bin/Graphics'

fileName='NVIDIA-Linux-x86_64-450.89-grid-azure.run'
curl -L -o $fileName $downloadUrl/$fileName
chmod +x $fileName
#./$fileName -s
