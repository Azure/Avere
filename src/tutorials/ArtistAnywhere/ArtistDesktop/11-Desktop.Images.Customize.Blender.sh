#!/bin/bash

set -ex

localDirectory='/usr/local/bin'
cd $localDirectory

storageDirectory='/mnt/tools/Blender'
mkdir -p $storageDirectory

fileName='blender279b.tar.bz2'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/release/Blender2.79/blender-2.79b-linux-glibc219-x86_64.tar.bz2'
fi
cp $storageDirectory/$fileName .
tar -xjf $fileName
mv blender-*/* .

fileName='blender2834.tar.xz'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/release/Blender2.83/blender-2.83.4-linux64.tar.xz'
fi
cp $storageDirectory/$fileName .
tar -xJf $fileName

# yum -y install libXi
# yum -y install libXrender
# yum -y install mesa-libGL
# yum -y install mesa-libGLU
