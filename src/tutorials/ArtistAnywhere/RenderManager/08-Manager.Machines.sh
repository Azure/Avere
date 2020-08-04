#!/bin/bash

set -ex

cd /usr/local/bin

export PGPASSWORD=$DB_ACCESS_TOKEN

tableExists=$(psql "$DB_SQL" -t -c "select to_regclass('public.show')")
if [ !$tableExists ]; then
    psql "$DB_SQL" -c "set aad_validate_oids_in_tenant = off; create role $DB_USER_NAME with login password '$DB_CLIENT_ID' in role azure_ad_user"
    psql "$DB_SQL" -c "alter default privileges in schema public grant all privileges on tables to $DB_USER_NAME"
    psql "$DB_SQL" -f opencue-bot-schema.sql
    psql "$DB_SQL" -f opencue-bot-data.sql
fi

sed -i "/Environment=DB_URL/c Environment=DB_URL=$DB_URL" opencue-bot.service
sed -i "/Environment=DB_USER/c Environment=DB_USER=$DB_USER_LOGIN" opencue-bot.service
sed -i "/Environment=JAR_PATH/c Environment=JAR_PATH=/usr/local/bin/opencue-bot.jar" opencue-bot.service

cat Manager.Machines.DataAccess.sh | sed 's|\r$||' | /bin/bash
