#!/bin/bash

set -ex

cd /usr/local/bin

echo "export CUEBOT_HOSTS=$RENDER_MANAGER_HOST" > /etc/profile.d/opencue.sh

if [ "$TERADICI_LICENSE_KEY" != "" ]; then
    pcoip-register-host --registration-code="$TERADICI_LICENSE_KEY"
    systemctl restart 'pcoip-agent'
fi
