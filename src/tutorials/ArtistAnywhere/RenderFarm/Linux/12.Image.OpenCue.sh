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
curl -L -o $fileName "$containerUrl/$fileName?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
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
