#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y install gcc
    dnf -y install python3-devel
else # centOS7
    yum -y install gcc
    yum -y install python3-devel
fi

fileName="OpenCue-v0.8.8.zip"
containerUrl="https://bit1.blob.core.windows.net/bin/OpenCue"
curl -L -o $fileName $containerUrl/$fileName
unzip $fileName

pip3 install --upgrade pip
pip3 install --upgrade setuptools

cd rqd-*
pip3 install --requirement "requirements.txt" --ignore-installed
cd ../pycue-*
python3 setup.py install
cd ../pyoutline-*
python3 setup.py install
cd ../rqd-*
python3 setup.py install
