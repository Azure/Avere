#!/bin/bash

set -ex

grep 'centos:7' /etc/os-release && centOS7=true || centOS7=false

if $centOS7; then
    yum -y groups install 'GNOME Desktop'
else # CentOS8
    dnf -y groups install 'Workstation'
fi
