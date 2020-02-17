#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$HOME_DIRECTORY"

tableCount=$(psql "$DB_DEPLOY_SQL" --command="select count(*) from information_schema.tables" --tuples-only)
if [ $tableCount -eq 0 ]
then
    psql "$DB_DEPLOY_SQL" --file=opencue-cuebot-schema.sql
    psql "$DB_DEPLOY_SQL" --file=opencue-cuebot-data.sql
fi

sed --in-place "/Environment=DB_URL/c Environment=DB_URL=$DB_CLIENT_URL" opencue-cuebot.service
sed --in-place "/Environment=DB_USER/c Environment=DB_USER=$DB_CLIENT_USERNAME" opencue-cuebot.service
sed --in-place "/Environment=DB_PASS/c Environment=DB_PASS=$DB_CLIENT_PASSWORD" opencue-cuebot.service
cp opencue-cuebot.service /etc/systemd/system

systemctl enable opencue-cuebot
systemctl start opencue-cuebot
