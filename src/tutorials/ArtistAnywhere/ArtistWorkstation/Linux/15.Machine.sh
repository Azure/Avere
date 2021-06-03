#!/bin/bash

set -ex

cd /usr/local/bin

echo "export CUEBOT_HOSTS=$renderManagerHost" > /etc/profile.d/opencue.sh

if [ "$teradiciLicenseKey" != "" ]; then
    yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
    yum -y install epel-release
    yum -y install usb-vhci
    yum -y install pcoip-agent-graphics
    pcoip-register-host --registration-code="$teradiciLicenseKey"
    systemctl restart 'pcoip-agent'
fi
