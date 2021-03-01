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
downloadUrl="https://bit1.blob.core.windows.net/bin/OpenCue"
curl -L -o $fileName $downloadUrl/$fileName
unzip $fileName

pip3 install --upgrade pip
pip3 install --upgrade setuptools
cd cuegui-*
pip3 install --requirement "requirements.txt" --ignore-installed
pip3 install --requirement "requirements_gui.txt"

cd ../pycue-*
python3 setup.py install
cd ../pyoutline-*
python3 setup.py install
cd ../cueadmin-*
python3 setup.py install
cd ../cuesubmit-*
python3 setup.py install
cd ../cuegui-*
python3 setup.py install
