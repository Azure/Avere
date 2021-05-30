#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y install nfs-utils
else # centOS7
    yum -y install nfs-utils
fi

lshw -class "display" | grep "NVIDIA" && gpuNVIDIA=true || gpuNVIDIA=false
if $gpuNVIDIA; then
    if $centOS8; then
        dnf -y install gcc
        dnf -y install make
        dnf -y install "kernel-devel-uname-r == $(uname -r)"
        dnf -y install epel-release
        dnf -y install dkms
    else # centOS7
        yum -y install gcc
        yum -y install "kernel-devel-uname-r == $(uname -r)"
    fi
    fileName="NVIDIA-Linux-x86_64-460.32.03-grid-azure.run"
    containerUrl="https://bit1.blob.core.windows.net/bin/Graphics/Linux"
    curl -L -o $fileName "$containerUrl/$fileName?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
    chmod +x $fileName
    ./$fileName -s
fi

cd /tmp
for mountFile in *.mount; do
    mountPath=$(echo $mountFile | cut -d. -f1)
    mountPath=$(echo $mountPath | tr "-" "/")
    mountPath="/$mountPath"
    mkdir -p $mountPath
    chmod 777 $mountPath
    cp $mountFile /etc/systemd/system
    systemctl enable $mountFile
done

localDirectoryPath="/mnt/storage"
storageAccountName="hpc02"
storageContainerName="show"

mkdir -p $localDirectoryPath
mount -o sec=sys,vers=3,nolock,proto=tcp $storageAccountName.blob.core.windows.net:/$storageAccountName/$storageContainerName $localDirectoryPath

fileName="lone-monk_cycles_and_exposure-node_demo.blend"
downloadUrl="https://download.blender.org/demo/cycles/$fileName"
curl -L -o $localDirectoryPath/$fileName $downloadUrl
