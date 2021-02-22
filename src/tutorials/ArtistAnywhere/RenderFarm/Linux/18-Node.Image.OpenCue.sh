#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:7" /etc/os-release && centOS7=true || centOS7=false
if $centOS7; then
    yum -y install gcc
    yum -y install python3-devel
else # CentOS8
    dnf -y install gcc
    dnf -y install python3-devel
fi

fileName="OpenCue-v0.8.8.zip"
downloadUrl="https://bit.blob.core.windows.net/bin/OpenCue"
curl -L -o $fileName $downloadUrl/$fileName
unzip $fileName

find . -type f -name *.pyc -delete
pip3 install --upgrade pip
pip3 install --upgrade setuptools

cd rqd-*
pip3 install --requirement "requirements.txt"
cd ../pycue-*
python3 setup.py install
cd ../pyoutline-*
python3 setup.py install
cd ../rqd-*
python3 setup.py install
