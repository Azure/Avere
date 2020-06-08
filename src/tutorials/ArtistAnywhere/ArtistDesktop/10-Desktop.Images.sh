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

fileName=opencue-requirements-gui.txt
fileUrl=https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements_gui.txt
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

fileName=opencue-admin.tar.gz
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cueadmin-0.4.14-all.tar.gz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-submit.tar.gz
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuesubmit-0.4.14-all.tar.gz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-gui.tar.gz
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuegui-0.4.14-all.tar.gz
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi
