#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:7" /etc/os-release && centOS7=true || centOS7=false
if $centOS7; then
    yum -y install nfs-utils
else # CentOS8
    dnf -y install nfs-utils
fi

lshw -class "display" | grep "NVIDIA" && gpuNVIDIA=true || gpuNVIDIA=false
if $gpuNVIDIA; then
    if $centOS8; then
        dnf -y install gcc
        dnf -y install make
        dnf -y install kernel-devel
        dnf -y install epel-release
        dnf -y install dkms
    else # CentOS7
        yum -y install gcc
        yum -y install kernel-devel
    fi
    downloadUrl="https://bit.blob.core.windows.net/bin/Graphics/Linux"
    fileName="NVIDIA-Linux-x86_64-460.32.03-grid-azure.run"
    curl -L -o $fileName $downloadUrl/$fileName
    chmod +x $fileName
    ./$fileName -s
fi
