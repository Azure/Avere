#!/bin/bash

set -ex

cd /usr/local/bin

fileName=blender.tar.xz
fileUrl=https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.3-linux64.tar.xz
curl -L -o $fileName $fileUrl

yum -y install libXi
yum -y install libXrender
yum -y install mesa-libGL
tar -xJf blender.tar.xz
mv blender-*/* .
