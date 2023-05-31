#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsCode="functions.sh"
functionsData="${filebase64("../0.Global.Foundation/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

if [ ${fileSystemMount.enable} == true ]; then
  SetMount "${fileSystemMount.storageRead}" "${fileSystemMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fileSystemMount.storageWrite}" "${fileSystemMount.storageWriteCache}" "${storageCache.enableWrite}"
  if [[ ${renderManager} == *Deadline* ]]; then
    AddMount "${fileSystemMount.schedulerDeadline}"
  fi
  mount -a
fi

EnableRenderClient "${renderManager}" "${servicePassword}"

if [ "${teradiciLicenseKey}" != "" ]; then
  /sbin/pcoip-register-host --registration-code=${teradiciLicenseKey} 2>&1 | tee pcoip-agent-license.log
fi
