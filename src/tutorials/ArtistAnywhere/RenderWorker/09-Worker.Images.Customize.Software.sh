#!/bin/bash

set -ex

cd /usr/local/bin

yum -y install nfs-utils

mkdir -p /mnt/tools
mount -t nfs -o rw,hard,rsize=65536,wsize=65536,vers=3,tcp 10.0.194.4:/tools /mnt/tools

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

fileName=opencue-pycue.tar.gz
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/pycue-0.4.14-all.tar.gz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-pyoutline.tar.gz
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/pyoutline-0.4.14-all.tar.gz
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

fileDirectory=/mnt/tools/blender/v2.83.2

fileName=blender.tar.xz
fileUrl=https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.2-linux64.tar.xz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi
