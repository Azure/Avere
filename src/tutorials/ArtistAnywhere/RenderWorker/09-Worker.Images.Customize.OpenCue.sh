#!/bin/bash

set -ex

cd /usr/local/bin

fileName='opencue-requirements.txt'
fileUrl='https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements.txt'
curl -L -o $fileName $fileUrl

fileName='opencue-pycue.tar.gz'
fileUrl='https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/pycue-0.4.14-all.tar.gz'
curl -L -o $fileName $fileUrl
tar -xzf $fileName
 
fileName='opencue-pyoutline.tar.gz'
fileUrl='https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/pyoutline-0.4.14-all.tar.gz'
curl -L -o $fileName $fileUrl
tar -xzf $fileName

fileName='opencue-rqd.tar.gz'
fileUrl='https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/rqd-0.4.14-all.tar.gz'
curl -L -o $fileName $fileUrl
tar -xzf $fileName

fileName='opencue-rqd.service'
fileUrl='https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/rqd/deploy/opencue-rqd.service'
curl -L -o $fileName $fileUrl

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
