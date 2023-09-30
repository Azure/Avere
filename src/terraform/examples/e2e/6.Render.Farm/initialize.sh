#!/bin/bash -x

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsCode="functions.sh"
functionsData="${filebase64("../0.Global.Foundation/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

SetFileSystems '${jsonencode(fileSystems)}'

EnableFarmClient

if [ ${terminateNotification.enable} == true ]; then
  cronFilePath="/tmp/crontab"
  echo "* * * * * /tmp/terminate.sh" > $cronFilePath
  crontab $cronFilePath
fi
