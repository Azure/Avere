#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:7" /etc/os-release && centOS7=true || centOS7=false

# if $centOS7; then
# else # CentOS8
# fi
