#!/bin/bash

gpuDriverUrl="https://bit1.blob.core.windows.net/bin/Graphics/Linux"
gpuDriver="NVIDIA-Linux-x86_64-460.32.03-grid-azure.run"

set -ex

cd /usr/local/bin

lshw -class "display" | grep "NVIDIA" && gpuNVIDIA=true || gpuNVIDIA=false
if $gpuNVIDIA; then
    grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
    if $centOS8; then
        dnf -y install gcc
        dnf -y install make
        dnf -y install "kernel-devel-uname-r == $(uname -r)"
        dnf -y install epel-release
        dnf -y install dkms
        dnf -y groups install "Workstation"
    else # centOS7
        yum -y install gcc
        yum -y install "kernel-devel-uname-r == $(uname -r)"
        yum -y groups install "GNOME Desktop"
    fi
    curl -L -o $gpuDriver $gpuDriverUrl/$gpuDriver
    chmod +x $gpuDriver
    ./$gpuDriver -s
fi
