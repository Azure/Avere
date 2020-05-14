#!/bin/bash -xe

cd /usr/local/bin

tableExists=$(psql "$DB_DEPLOY_SQL" -t -c "select to_regclass('public.show')")
if [ !$tableExists ]
then
    psql "$DB_DEPLOY_SQL" -f opencue-cuebot-schema.sql
    psql "$DB_DEPLOY_SQL" -f opencue-cuebot-data.sql
fi

sed -i "/Environment=DB_URL/c Environment=DB_URL=$DB_CLIENT_URL" opencue-cuebot.service
sed -i "/Environment=DB_USER/c Environment=DB_USER=$DB_CLIENT_USERNAME" opencue-cuebot.service
sed -i "/Environment=DB_PASS/c Environment=DB_PASS=$DB_CLIENT_PASSWORD" opencue-cuebot.service
sed -i "/Environment=JAR_PATH/c Environment=JAR_PATH=/usr/local/bin/opencue-cuebot.jar" opencue-cuebot.service
cp opencue-cuebot.service /etc/systemd/system

systemctl enable opencue-cuebot
systemctl start opencue-cuebot
