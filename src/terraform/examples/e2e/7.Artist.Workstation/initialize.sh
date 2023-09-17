#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsCode="functions.sh"
functionsData="${filebase64("../0.Global.Foundation/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

fileSystemMounts='${jsonencode(fileSystemMounts)}'
for fileSystemMount in $(echo $fileSystemMounts | jq -r '.[] | @base64'); do
  if [ $(GetEncodedValue $fileSystemMount .enable) == true ]; then
    SetFileSystemMount "$(GetEncodedValue $fileSystemMount .mount)"
  fi
done
mount -a

EnableFarmClient

if [ "${teradiciLicenseKey}" != "" ]; then
  StartProcess "/sbin/pcoip-register-host --registration-code=${teradiciLicenseKey}" $binDirectory/pcoip-agent-license
fi
