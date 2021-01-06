#!/bin/bash

set -ex

grep 'centos:7' /etc/os-release && centOS7=true || centOS7=false
lshw -class 'display' | grep 'NVIDIA' && nvidiaGPU=true || nvidiaGPU=false

if $centOS7; then
    yum -y install nfs-utils
    yum -y install unzip
else # CentOS8
    dnf -y install nfs-utils
fi

cd /usr/local/bin

if $nvidiaGPU; then
    dnf -y install gcc
    downloadUrl='https://mediasolutions.blob.core.windows.net/bin/GPU'
    fileName='NVIDIA-Linux-x86_64-450.89-grid-azure.run'
    curl -L -o $fileName $downloadUrl/$fileName
    chmod +x $fileName
    #./$fileName -s
fi

downloadUrl='https://mediasolutions.blob.core.windows.net/bin/Blender'

mountDirectory='/mnt/storage/read'

mkdir -p $mountDirectory

mount -t nfs -o rw,hard,rsize=1048576,wsize=1048576,vers=3,tcp 10.0.1.4:/volume-a $mountDirectory

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

cd /tmp
for mountFile in *.mount; do
    mountPath=$(echo $mountFile | cut -d. -f1)
    mountPath=$(echo $mountPath | tr '-' '/')
    mountPath="/$mountPath"
    mkdir -p $mountPath
    chmod 777 $mountPath
    cp $mountFile /usr/lib/systemd/system
    systemctl enable $mountFile
done
