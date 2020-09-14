#!/bin/bash

set -ex

localDirectory='/usr/local/bin/OpenCue'
mkdir -p $localDirectory
cd $localDirectory

storageDirectory='/mnt/tools/OpenCue/v0.4.55'
mkdir -p $storageDirectory

fileName='opencue-requirements.txt'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements.txt'
fi
cp $storageDirectory/$fileName .

fileName='opencue-pycue.tar.gz'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/pycue-0.4.55-all.tar.gz'
fi
cp $storageDirectory/$fileName .
tar -xzf $fileName

fileName='opencue-pyoutline.tar.gz'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/pyoutline-0.4.55-all.tar.gz'
fi
cp $storageDirectory/$fileName .
tar -xzf $fileName

fileName='opencue-rqd.tar.gz'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/rqd-0.4.55-all.tar.gz'
fi
cp $storageDirectory/$fileName .
tar -xzf $fileName

fileName='opencue-rqd.service'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/rqd/deploy/opencue-rqd.service'
fi
cp $storageDirectory/$fileName .

yum -y install gcc
if [ "$(cat /etc/os-release | grep 'centos:8')" ]; then
    yum -y install python3-devel
    yum -y install redhat-rpm-config
    pip3 install -r 'opencue-requirements.txt'
    find . -type f -name *.pyc -delete
    cd pycue-*
    python3 setup.py install
    cd ../pyoutline-*
    python3 setup.py install
    cd ../rqd-*
    python3 setup.py install
else
    yum -y install python-devel
    yum -y install python-pip
    pip install -U pip
    pip install -Ir 'opencue-requirements.txt'
    find . -type f -name *.pyc -delete
    cd pycue-*
    python setup.py install
    cd ../pyoutline-*
    python setup.py install
    cd ../rqd-*
    python setup.py install
fi
