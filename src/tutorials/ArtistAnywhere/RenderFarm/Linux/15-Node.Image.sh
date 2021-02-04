#!/bin/bash

set -ex

cd /usr/local/bin

grep 'centos:7' /etc/os-release && centOS7=true || centOS7=false
lshw -class 'display' | grep 'NVIDIA' && nvidiaGPU=true || nvidiaGPU=false

if $centOS7; then
    yum -y install nfs-utils
else # CentOS8
    dnf -y install nfs-utils
fi

cd /tmp
for mountFile in *.mount; do
    mountPath=$(echo $mountFile | cut -d. -f1)
    mountPath=$(echo $mountPath | tr '-' '/')
    mountPath="/$mountPath"
    mkdir -p $mountPath
    chmod 777 $mountPath
    cp $mountFile /etc/systemd/system
    systemctl enable $mountFile
done

if $nvidiaGPU; then
    dnf -y install gcc
    downloadUrl='https://usawest.blob.core.windows.net/bin/Graphics'
    fileName='NVIDIA-Linux-x86_64-450.89-grid-azure.run'
    curl -L -o $fileName $downloadUrl/$fileName
    chmod +x $fileName
    #./$fileName -s
fi

downloadUrl='https://usawest.blob.core.windows.net/bin/Blender'

mountDirectory='/mnt/storage/object'

fileName='bmw27_cpu.blend'
curl -L -o $fileName $downloadUrl/$fileName
cp $fileName $mountDirectory

fileName='bmw27_gpu.blend'
curl -L -o $fileName $downloadUrl/$fileName
cp $fileName $mountDirectory

fileName='barbershop_interior_cpu.blend'
curl -L -o $fileName $downloadUrl/$fileName
cp $fileName $mountDirectory

fileName='barbershop_interior_gpu.blend'
curl -L -o $fileName $downloadUrl/$fileName
cp $fileName $mountDirectory

fileName='classroom.zip'
curl -L -o $fileName $downloadUrl/$fileName
cp $fileName $mountDirectory
unzip $mountDirectory/$fileName

umount $mountDirectory
rmdir $mountDirectory
