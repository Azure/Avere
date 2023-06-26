#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsCode="functions.sh"
functionsData="${filebase64("../0.Global.Foundation/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

SetServiceAccount ${serviceAccountName} ${serviceAccountPassword}

fileSystemMounts='${jsonencode(fileSystemMounts)}'
for fileSystemMount in $(echo $fileSystemMounts | jq -r '.[] | @base64'); do
  if [ $(GetEncodedValue $fileSystemMount .enable) == true ]; then
    SetFileSystemMount "$(GetEncodedValue $fileSystemMount .mount)"
  fi
done
mount -a

EnableClientApp "${renderManager}" ${serviceAccountName} ${serviceAccountPassword}

if [ ${terminateNotification.enable} == true ]; then
  cronFilePath="/tmp/crontab"
  echo "* * * * * /tmp/terminate.sh" > $cronFilePath
  crontab $cronFilePath
fi
