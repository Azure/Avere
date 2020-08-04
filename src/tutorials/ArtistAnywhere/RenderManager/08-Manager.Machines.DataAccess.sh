#!/bin/bash

set -ex

cd /usr/local/bin

dbAccessToken=$(curl -s -H Metadata:true 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fossrdbms-aad.database.windows.net' | jq -r .access_token)

sed -i "/Environment=DB_PASS/c Environment=DB_PASS=$dbAccessToken" opencue-bot.service

cp opencue-bot.service /etc/systemd/system

systemctl enable opencue-bot
systemctl reload-or-restart opencue-bot
