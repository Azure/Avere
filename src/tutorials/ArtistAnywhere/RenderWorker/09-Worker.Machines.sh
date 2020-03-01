#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$HOME_DIRECTORY"

sed --in-place "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER_HOST" opencue-rqd.service
cp opencue-rqd.service /etc/systemd/system

systemctl enable opencue-rqd
systemctl start opencue-rqd

IFS='|' read -a cacheMounts <<< "$CACHE_MOUNTS"
for cacheMount in "${cacheMounts[@]}"
do
	localPath="$(cut --delimiter ' ' --fields 2 <<< $cacheMount)"
	mkdir --parents $localPath
	echo $cacheMount >> /etc/fstab
done
mount --all
