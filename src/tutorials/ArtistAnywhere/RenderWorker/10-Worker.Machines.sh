#!/bin/bash

set -ex

cd /usr/local/bin/OpenCue

mkdir /shots
chmod 777 /shots

systemService='opencue-rqd.service'
sed -i "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER_HOST" $systemService
cp $systemService /etc/systemd/system

systemctl enable $systemService
systemctl start $systemService

IFS=';' read -a fileSystemMounts <<< "$FILE_SYSTEM_MOUNTS"
for fileSystemMount in "${fileSystemMounts[@]}"
do
    IFS=' ' read -a fsTabMount <<< "$fileSystemMount"
    directoryPath="${fsTabMount[1]}"
    mkdir -p $directoryPath
    echo $fileSystemMount >> /etc/fstab
done
for i in {1..100}; do
    mount -a
    if [ $? -eq 0 ]; then
        break
    fi
    sleep 3
done
