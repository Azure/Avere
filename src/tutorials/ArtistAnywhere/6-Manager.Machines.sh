#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$APP_DIRECTORY"

if [ "$DB_CONNECTION" -ne "" ]
then
    psql "$DB_CONNECTION" --file=opencue-cuebot-schema.sql
    psql "$DB_CONNECTION" --file=opencue-cuebot-data.sql
fi

systemctl enable opencue-cuebot
systemctl start opencue-cuebot