#!/bin/bash

set -ex

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
if $centOS8; then
    dnf -y groups install 'Workstation'
else # centOS7
    yum -y groups install 'GNOME Desktop'
fi
