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
        dnf -y install kernel-devel
        dnf -y install epel-release
        dnf -y install dkms
    else # centOS7
        yum -y install gcc
        yum -y install kernel-devel
    fi
    downloadUrl="https://bit1.blob.core.windows.net/bin/Graphics/Linux"
    fileName="NVIDIA-Linux-x86_64-460.32.03-grid-azure.run"
    curl -L -o $fileName $downloadUrl/$fileName
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

# downloadUrl="https://bit1.blob.core.windows.net/bin/Blender"

# mountDirectory="/mnt/storage/object"

# fileName="bmw27_cpu.blend"
# curl -L -o $fileName $downloadUrl/$fileName
# cp $fileName $mountDirectory

# fileName="bmw27_gpu.blend"
# curl -L -o $fileName $downloadUrl/$fileName
# cp $fileName $mountDirectory

# fileName="barbershop_interior_cpu.blend"
# curl -L -o $fileName $downloadUrl/$fileName
# cp $fileName $mountDirectory

# fileName="barbershop_interior_gpu.blend"
# curl -L -o $fileName $downloadUrl/$fileName
# cp $fileName $mountDirectory

# fileName="classroom.zip"
# curl -L -o $fileName $downloadUrl/$fileName
# cp $fileName $mountDirectory
# unzip $mountDirectory/$fileName

# umount $mountDirectory
# rmdir $mountDirectory
