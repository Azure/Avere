#!/bin/bash

set -ex

localDirectory='/usr/local/bin'
cd $localDirectory

dbName=$(echo "${DB_NAME,,}")

pgAdmin="host=$DATA_HOST port=$DATA_PORT sslmode=require dbname=postgres $ADMIN_AUTH"
dbAdmin="host=$DATA_HOST port=$DATA_PORT sslmode=require dbname=$dbName $ADMIN_AUTH"

databaseExists=$(psql "$pgAdmin" -t -c "select datname from pg_catalog.pg_database where lower(datname) = '$dbName'")
if [ ! $databaseExists ]; then
    psql "$pgAdmin" -c "create database $dbName"
    psql "$dbAdmin" -c "create user $DB_USER_NAME with password '$DB_USER_PASSWORD'"
    psql "$dbAdmin" -c "alter default privileges in schema public grant all privileges on tables to $DB_USER_NAME"
    psql "$dbAdmin" -f opencue-bot-schema.sql
    psql "$dbAdmin" -f opencue-bot-data.sql
fi

systemService='opencue-bot.service'

dbUrl="jdbc:postgresql://$DATA_HOST:$DATA_PORT/$dbName?sslmode=require"
sed -i "/Environment=DB_URL/c Environment=DB_URL=$dbUrl" $systemService
sed -i "/Environment=DB_USER/c Environment=DB_USER=$DB_USER_NAME" $systemService
sed -i "/Environment=DB_PASS/c Environment=DB_PASS=$DB_USER_PASSWORD" $systemService
sed -i "/Environment=JAR_PATH/c Environment=JAR_PATH=$localDirectory/opencue-bot.jar" $systemService

cp $systemService /etc/systemd/system
systemctl enable $systemService
systemctl start $systemService
