#!/bin/bash -xe

cd /usr/local/bin

sed -i "/Environment=BIN/c Environment=BIN=/usr/local/bin" opencue-rqd.service
sed -i "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER_HOST" opencue-rqd.service
cp opencue-rqd.service /etc/systemd/system

systemctl enable opencue-rqd
systemctl start opencue-rqd

IFS=';' read -a fileSystemMounts <<< "$FILE_SYSTEM_MOUNTS"
for fileSystemMount in "${fileSystemMounts[@]}"
do
    localPath="$(cut -d ' ' -f 2 <<< $fileSystemMount)"
    mkdir -p $localPath
    echo $fileSystemMount >> /etc/fstab
done
mount -a
