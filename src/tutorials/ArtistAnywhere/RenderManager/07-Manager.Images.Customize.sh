#!/bin/bash

set -ex

yum -y install epel-release
yum -y install jq

mv /tmp/Manager.Machines.DataAccess.sh /usr/local/bin

echo "0 0 * * * root /usr/local/bin/Manager.Machines.DataAccess.sh" > /var/spool/cron/root
