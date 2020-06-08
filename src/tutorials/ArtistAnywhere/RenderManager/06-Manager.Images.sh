#!/bin/bash

set -ex

cd /usr/local/bin

fileDirectory=/mnt/tools/opencue/v0.4.14

fileName=opencue-bot-schema.sql
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/schema-0.4.14.sql
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-bot-data.sql
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/demo_data-0.4.14.sql
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-bot.jar
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuebot-0.4.14-all.jar
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi

fileName=opencue-bot.service
fileUrl=https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/cuebot/deploy/systemd/opencue-cuebot.service
if [ ! -f $fileDirectory/$fileName ]; then
    curl -L -o $fileName $fileUrl
    mkdir -p $fileDirectory
    cp $fileName $fileDirectory
else
    cp $fileDirectory/$fileName .
fi
