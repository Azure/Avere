#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y install java-11-openjdk
    dnf -y module disable postgresql
    dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dnf -y install postgresql12
else # centOS7
    yum -y install java-11-openjdk
    yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    yum -y install postgresql12
fi

fileName="OpenCue-v0.8.8.zip"
containerUrl="https://bit1.blob.core.windows.net/bin/OpenCue"
curl -L -o $fileName $containerUrl/$fileName
unzip $fileName
