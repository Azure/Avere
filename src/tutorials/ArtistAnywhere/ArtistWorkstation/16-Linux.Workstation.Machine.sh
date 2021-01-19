#!/bin/bash

set -ex

cd /usr/local/bin

echo "export CUEBOT_HOSTS=$RENDER_MANAGER_HOST" > /etc/profile.d/opencue.sh

if [ "$TERADICI_LICENSE_KEY" != "" ]; then
    yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
    yum -y install epel-release
    yum -y install usb-vhci
    yum -y install pcoip-agent-graphics
    pcoip-register-host --registration-code="$TERADICI_LICENSE_KEY"
    systemctl restart 'pcoip-agent'
fi
