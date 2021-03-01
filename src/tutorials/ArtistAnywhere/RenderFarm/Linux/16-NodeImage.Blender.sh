#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y install libXi
    dnf -y install libXxf86vm
    dnf -y install libXfixes
    dnf -y install libXrender
    dnf -y install libGL
else # centOS7
    yum -y install libXi
    yum -y install libXxf86vm
    yum -y install libXfixes
    yum -y install libXrender
    yum -y install libGL
fi

fileName="blender-2.92.0-linux64.tar.xz"
downloadUrl="https://bit1.blob.core.windows.net/bin/Blender"
curl -L -o $fileName $downloadUrl/$fileName
tar -xJf $fileName
mv blender-*/* .
