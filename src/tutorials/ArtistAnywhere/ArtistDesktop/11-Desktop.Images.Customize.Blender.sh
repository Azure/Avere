#!/bin/bash

set -ex

localDirectory='/usr/local/bin'
cd $localDirectory

storageDirectory='/mnt/tools/Blender'
mkdir -p $storageDirectory

fileName='blender2835.tar.xz'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/release/Blender2.83/blender-2.83.5-linux64.tar.xz'
fi
cp $storageDirectory/$fileName .
tar -xJf $fileName
mv blender-*/* .

# yum -y install libXi
# yum -y install libXrender
# yum -y install mesa-libGL
