#!/bin/bash

set -ex

cd /usr/local/bin

fileName=opencue-bot-schema.sql
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/schema-0.4.14.sql
curl -L -o $fileName $fileUrl

fileName=opencue-bot-data.sql
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/demo_data-0.4.14.sql
curl -L -o $fileName $fileUrl

fileName=opencue-bot.jar
fileUrl=https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuebot-0.4.14-all.jar
curl -L -o $fileName $fileUrl

fileName=opencue-bot.service
fileUrl=https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/cuebot/deploy/systemd/opencue-cuebot.service
curl -L -o $fileName $fileUrl

yum -y install java-11-openjdk
yum -y install postgresql-contrib
