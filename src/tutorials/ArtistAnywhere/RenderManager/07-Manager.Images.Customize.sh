#!/bin/bash

set -ex

if [ "$(cat /etc/os-release | grep 'centos:7')" ]; then
    yum -y install epel-release
fi
yum -y install jq

mv /tmp/Manager.Machines.DataAccess.sh /usr/local/bin

echo "0 0 * * * root /usr/local/bin/Manager.Machines.DataAccess.sh" > /var/spool/cron/root
