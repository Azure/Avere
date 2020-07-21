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

fileName=blender.msi
fileUrl=https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.2-windows64.msi
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileDirectory=/mnt/tools/blender/scenes/eevee

fileName=color-vortex.blend
fileUrl=https://download.blender.org/demo/color_vortex.blend
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=mr-elephant.blend
fileUrl=https://download.blender.org/demo/eevee/mr_elephant/mr_elephant.blend
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileDirectory=/mnt/tools/blender/scenes/cycles

fileName=classroom.zip
fileUrl=https://download.blender.org/demo/test/classroom.zip
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=pavillion.zip
fileUrl=https://download.blender.org/demo/test/pabellon_barcelona_v1.scene_.zip
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileDirectory=/mnt/tools/teradici/v20.04.01

fileName=teradici-agent-standard.exe
fileUrl=https://mediasolutions.blob.core.windows.net/bin/pcoip-agent-standard_20.04.1.exe
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=teradici-agent-graphics.exe
fileUrl=https://mediasolutions.blob.core.windows.net/bin/pcoip-agent-graphics_20.04.1.exe
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi
