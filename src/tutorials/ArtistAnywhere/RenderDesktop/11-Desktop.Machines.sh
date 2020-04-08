#!/bin/bash -xe

if [ "$TERADICI_DESKTOP_ENVIRONMENT" != "" ]
then
    yum -y groups install $TERADICI_DESKTOP_ENVIRONMENT
fi

yum -y install $TERADICI_REPOSITORY_URL
yum -y install $TERADICI_HOST_AGENT_NAME

if [ "$TERADICI_HOST_AGENT_KEY" != "" ]
then
    pcoip-register-host --registration-code=$TERADICI_HOST_AGENT_KEY
fi

echo "export CUEBOT_HOSTS=$OPENCUE_RENDER_MANAGER_HOST" > /etc/profile.d/opencue.sh

shutdown -r 0
