#!/bin/bash

set -ex

if [ "$TERADICI_LICENSE_KEY" != "" ]; then
    pcoip-register-host --registration-code="$TERADICI_LICENSE_KEY"
    systemctl restart 'pcoip-agent'
fi
