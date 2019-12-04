#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

cd "$ROOT_DIRECTORY"

sed --in-place "/Environment=OPTIONS=/i Environment=CUEBOT_HOSTNAME=$RENDER_MANAGER" opencue-rqd.service
sed --in-place '/SyslogIdentifier/a RestartSec=30' opencue-rqd.service
sed --in-place '/SyslogIdentifier/a Restart=always' opencue-rqd.service
cp opencue-rqd.service /etc/systemd/system

systemctl enable opencue-rqd
systemctl start opencue-rqd

cd /etc
sed --in-place "/auto.misc/i /-\t/etc/auto.render" auto.master

cp auto.misc auto.render
IFS='|' read -a cacheMounts <<< "$CACHE_MOUNTS"
for cacheMount in "${cacheMounts[@]}"
do
	autoMount="$(sed 's|;|\t|g' <<< $cacheMount)"
	sed --in-place "/fstype=iso9660/i $autoMount" auto.render
	mountPath="$(cut --delimiter ';' --fields 1 <<< $cacheMount)"
	mkdir --parents $mountPath
done

systemctl enable autofs
systemctl start autofs