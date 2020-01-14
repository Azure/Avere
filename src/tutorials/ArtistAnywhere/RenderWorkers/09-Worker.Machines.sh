#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$ROOT_DIRECTORY"

sed --in-place "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER" opencue-rqd.service
cp opencue-rqd.service /etc/systemd/system

systemctl enable opencue-rqd
systemctl start opencue-rqd

cd /etc
sed --in-place "/auto.misc/i /-\t/etc/auto.render" auto.master

cp auto.misc auto.render
IFS='|' read -a storageMounts <<< "$STORAGE_MOUNTS"
for storageMount in "${storageMounts[@]}"
do
	autoMount="$(sed 's|;|\t|g' <<< $storageMount)"
	sed --in-place "/fstype=iso9660/i $autoMount" auto.render
	mountPath="$(cut --delimiter ';' --fields 1 <<< $storageMount)"
	mkdir --parents $mountPath
done

chmod -R 0777 /storage

systemctl enable autofs
systemctl start autofs