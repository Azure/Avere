#!/bin/bash

set -ex

localDirectory='/usr/bin'
cd $localDirectory

storageDirectory='/mnt/tools/Blender'
mkdir -p $storageDirectory

fileName='blender2834.tar.xz'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.4-linux64.tar.xz'
fi
cp $storageDirectory/$fileName .
tar -xJf $fileName
