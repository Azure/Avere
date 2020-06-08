#!/bin/bash

set -ex

cd /usr/local/bin

fileDirectory=/mnt/tools/blender/v2.83.0

fileName=blender.tar.xz
fileUrl=https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.0-linux64.tar.xz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileDirectory=/mnt/tools/opencue/v0.4.14

fileName=opencue-requirements.txt
fileUrl=https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements.txt
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-rqd.tar.gz
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/rqd-0.4.14-all.tar.gz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-rqd.service
fileUrl=https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/rqd/deploy/opencue-rqd.service
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi
