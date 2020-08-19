#!/bin/bash

set -ex

cd /usr/local/bin

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
    sleep 1
done

echo "export CUEBOT_HOSTS=$RENDER_MANAGER_HOST" > /etc/profile.d/opencue.sh

if [ "$TERADICI_AGENT_KEY" != "" ]; then
    # yum -y install 'https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm'
    # curl -L -o epel-release-latest-7.noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    # rpm -i epel-release-latest-7.noarch.rpm
    # yum -y install usb-vhci
    yum -y install "$TERADICI_AGENT"
    pcoip-register-host --registration-code="$TERADICI_AGENT_KEY"
    systemctl restart 'pcoip-agent'
fi
