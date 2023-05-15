#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsCode="functions.sh"
functionsData="${filebase64("../0.global/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

if [ "${fileSystemMount.enable}" == "true" ]; then
  SetMount "${fileSystemMount.storageRead}" "${fileSystemMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fileSystemMount.storageWrite}" "${fileSystemMount.storageWriteCache}" "${storageCache.enableWrite}"
  if [[ ${renderManager} == *Deadline* ]]; then
    AddMount "${fileSystemMount.schedulerDeadline}"
  fi
  mount -a
fi

EnableRenderClient "${renderManager}" "${servicePassword}"

if [ "${terminateNotification.enable}" == "true" ]; then
  cronFilePath="/tmp/crontab"
  echo "* * * * * /tmp/terminate.sh" > $cronFilePath
  crontab $cronFilePath
fi
