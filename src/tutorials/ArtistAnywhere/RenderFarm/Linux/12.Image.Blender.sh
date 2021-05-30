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
containerUrl="https://bit1.blob.core.windows.net/bin/Blender"
curl -L -o $fileName "$containerUrl/$fileName?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
tar -xJf $fileName
mv blender-*/* .
