#!/bin/bash

set -ex

cd /usr/local/bin

grep "centos:8" /etc/os-release && centOS8=true || centOS8=false
# if $centOS8; then
# else # centOS7
# fi
