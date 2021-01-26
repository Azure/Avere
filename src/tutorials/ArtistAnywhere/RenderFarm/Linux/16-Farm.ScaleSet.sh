#!/bin/bash

set -ex

localDirectory='/usr/local/bin'
cd $localDirectory

systemService='opencue-rqd.service'
sed -i "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER_HOST" $systemService
sed -i "/Environment=BIN=/c Environment=BIN=$localDirectory" $systemService
cp $systemService /etc/systemd/system

systemctl enable $systemService
systemctl start $systemService

mkdir /shots
chmod 777 /shots
