#!/bin/bash

set -ex

localDirectory='/usr/local/bin/OpenCue'
mkdir -p $localDirectory
cd $localDirectory

storageDirectory='/mnt/tools/OpenCue/v0.4.14'
mkdir -p $storageDirectory

fileName='opencue-bot-schema.sql'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/schema-0.4.14.sql'
fi
cp $storageDirectory/$fileName .

fileName='opencue-bot-data.sql'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/demo_data-0.4.14.sql'
fi
cp $storageDirectory/$fileName .

fileName='opencue-bot.jar'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuebot-0.4.14-all.jar'
fi
cp $storageDirectory/$fileName .

fileName='opencue-bot.service'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/cuebot/deploy/systemd/opencue-cuebot.service'
fi
cp $storageDirectory/$fileName .

yum -y install java-11-openjdk
yum -y install postgresql-contrib
