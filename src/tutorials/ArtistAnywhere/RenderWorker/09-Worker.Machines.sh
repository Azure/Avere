#!/bin/bash

set -ex

cd /usr/local/bin

sed -i "/Environment=BIN/c Environment=BIN=/usr/local/bin" opencue-rqd.service
sed -i "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER_HOST" opencue-rqd.service
cp opencue-rqd.service /etc/systemd/system

systemctl enable opencue-rqd
systemctl start opencue-rqd

IFS=';' read -a fileSystemMounts <<< "$FILE_SYSTEM_MOUNTS"
for fileSystemMount in "${fileSystemMounts[@]}"
do
    IFS=' ' read -a fsTabMount <<< "$fileSystemMount"
    directoryPath="${fsTabMount[1]}"
    mkdir -p $directoryPath
    echo $fileSystemMount >> /etc/fstab
done
mount -a

IFS=';' read -a fileSystemMounts <<< "$FILE_SYSTEM_MOUNTS"
for fileSystemMount in "${fileSystemMounts[@]}"
do
    IFS=' ' read -a fsTabMount <<< "$fileSystemMount"
    directoryPath="${fsTabMount[1]}"
    directoryPermissions="${fsTabMount[-1]}"
    chmod $directoryPermissions $directoryPath
done
