#!/bin/bash

set -ex

cd /usr/local/bin

fileName='blender.tar.xz'
fileUrl='https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.3-linux64.tar.xz'
curl -L -o $fileName $fileUrl
tar -xJf $fileName

fileName='color-vortex.blend'
fileUrl='https://download.blender.org/demo/color_vortex.blend'
curl -L -o $fileName $fileUrl

fileName='mr-elephant.blend'
fileUrl='https://download.blender.org/demo/eevee/mr_elephant/mr_elephant.blend'
curl -L -o $fileName $fileUrl

fileName='classroom.zip'
fileUrl='https://download.blender.org/demo/test/classroom.zip'
curl -L -o $fileName $fileUrl

fileName='pavillion.zip'
fileUrl='https://download.blender.org/demo/test/pabellon_barcelona_v1.scene_.zip'
curl -L -o $fileName $fileUrl

yum -y install libXi
yum -y install libXrender
yum -y install mesa-libGL
mv blender-*/* .
