#!/bin/bash

set -ex

yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
yum -y install epel-release
yum -y install usb-vhci
yum -y install pcoip-agent-graphics

if [ "$TERADICI_LICENSE_KEY" != "" ]; then
    pcoip-register-host --registration-code="$TERADICI_LICENSE_KEY"
fi

systemctl restart 'pcoip-agent'
