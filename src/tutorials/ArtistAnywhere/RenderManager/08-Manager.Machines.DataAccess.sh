#!/bin/bash

set -ex

cd /usr/local/bin/OpenCue

dbAccessToken=$(curl -s -H Metadata:true 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fossrdbms-aad.database.windows.net' | jq -r .access_token)

systemService='opencue-bot.service'
sed -i "/Environment=DB_PASS/c Environment=DB_PASS=$dbAccessToken" $systemService

cp $systemService /etc/systemd/system

systemctl enable $systemService
systemctl reload-or-restart $systemService
