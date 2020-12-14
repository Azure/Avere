#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'CentOS-7')" ]; then
    yum -y install nfs-utils
    yum -y install unzip
elif [ "$(cat /etc/os-release | grep 'CentOS-8')" ]; then
    dnf -y install nfs-utils
    dnf -y install unzip
fi

cd /usr/local/bin

downloadUrl='https://mediasolutions.blob.core.windows.net/bin/Blender'

mountDirectory='/mnt/storage'

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
