#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:7" /etc/os-release && centOS7=true || centOS7=false

if $centOS7; then
    yum -y install libXi
    yum -y install libXxf86vm
    yum -y install libXfixes
    yum -y install libXrender
    yum -y install libGL
else # CentOS8
    dnf -y install libXi
    dnf -y install libXxf86vm
    dnf -y install libXfixes
    dnf -y install libXrender
    dnf -y install libGL
fi

downloadUrl="https://bit.blob.core.windows.net/bin/Blender"

fileName="blender-2.91.2-linux64.tar.xz"
curl -L -o $fileName $downloadUrl/$fileName
tar -xJf $fileName
mv blender-*/* .
