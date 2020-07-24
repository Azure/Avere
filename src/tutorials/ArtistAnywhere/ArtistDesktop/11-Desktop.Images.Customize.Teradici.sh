#!/bin/bash

set -ex

yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
yum -y install pcoip-agent-standard
yum -y install pcoip-agent-graphics
