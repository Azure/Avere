#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$ROOT_DIRECTORY"

if [ "$DB_ADMIN_CONNECTION" -ne "" ]
then
    psql "$DB_ADMIN_CONNECTION" --file=opencue-cuebot-schema.sql
    psql "$DB_ADMIN_CONNECTION" --file=opencue-cuebot-data.sql
fi

systemctl enable opencue-cuebot
systemctl start opencue-cuebot