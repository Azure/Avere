#!/bin/bash

set -ex

cd /usr/local/bin

yum -y install libXi
yum -y install libXrender
yum -y install mesa-libGL
tar -xJf blender.tar.xz
mv blender-*/* .

yum -y install gcc
if [ "$(cat /etc/os-release | grep 'centos:8')" ]; then
    yum -y install python3-devel
    yum -y install redhat-rpm-config
    yum -y groups install 'Workstation'
    pip3 install -r opencue-requirements.txt
    tar -xzf opencue-pycue.tar.gz
    tar -xzf opencue-pyoutline.tar.gz
    find . -type f -name '*.pyc' -delete
    cd pycue-*
    python3 setup.py install
    cd ../pyoutline-*
    python3 setup.py install
    cd ../cueadmin-*
    python3 setup.py install
    cd ../cuesubmit-*
    python3 setup.py install
    cd ../cuegui-*
    python3 setup.py install
else
    yum -y install epel-release
    yum -y install python-devel
    yum -y install python-pip
    yum -y groups install 'GNOME Desktop'
    pip install -U pip
    pip install -Ir opencue-requirements.txt
    tar -xzf opencue-pycue.tar.gz
    tar -xzf opencue-pyoutline.tar.gz
    tar -xzf opencue-rqd.tar.gz
    find . -type f -name '*.pyc' -delete
    cd pycue-*
    python setup.py install
    cd ../pyoutline-*
    python setup.py install
    cd ../rqd-*
    python setup.py install
fi
