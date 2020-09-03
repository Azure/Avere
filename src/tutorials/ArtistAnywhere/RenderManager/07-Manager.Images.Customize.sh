#!/bin/bash

set -ex

localDirectory='/usr/local/bin'
cd $localDirectory

if [ "$(cat /etc/os-release | grep 'CentOS-7')" ]; then
    yum -y install epel-release
    yum -y install jq
elif [ "$(cat /etc/os-release | grep 'CentOS-8')" ]; then
    dnf -y install epel-release
    dnf -y install jq
fi

mv /tmp/Manager.Machines.DataAccess.sh $localDirectory
echo "0 0 * * * root $localDirectory/Manager.Machines.DataAccess.sh" > /var/spool/cron/root
