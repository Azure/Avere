#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$ROOT_DIRECTORY"

sed --in-place "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER" opencue-rqd.service
sed --in-place '/SyslogIdentifier/a RestartSec=30' opencue-rqd.service
sed --in-place '/SyslogIdentifier/a Restart=always' opencue-rqd.service
cp opencue-rqd.service /etc/systemd/system

systemctl enable opencue-rqd
systemctl start opencue-rqd