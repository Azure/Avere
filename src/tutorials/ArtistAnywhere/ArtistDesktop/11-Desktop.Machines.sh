#!/bin/bash -xe

if [ "$TERADICI_HOST_AGENT_LICENSE_KEY" != "" ]
then
    yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
    yum -y install $TERADICI_HOST_AGENT_NAME
    pcoip-register-host --registration-code=$TERADICI_HOST_AGENT_LICENSE_KEY
    systemctl restart pcoip-agent
fi

echo "export CUEBOT_HOSTS=$OPENCUE_RENDER_MANAGER_HOST" > /etc/profile.d/opencue.sh

IFS=';' read -a fileSystemMounts <<< "$FILE_SYSTEM_MOUNTS"
for fileSystemMount in "${fileSystemMounts[@]}"
do
    localPath="$(cut -d ' ' -f 2 <<< $fileSystemMount)"
    mkdir -p $localPath
    echo $fileSystemMount >> /etc/fstab
done
mount -a
