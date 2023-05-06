#!/bin/bash -ex

source /etc/profile.d/aaa.sh

cd /usr/local/bin

functionsCode="functions.sh"
functionsData="${filebase64("../0.global/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

if [ "${fsMount.enable}" == "true" ]; then
  SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
  if [[ ${renderManager} == *Deadline* ]]; then
    AddMount "${fsMount.schedulerDeadline}"
  fi
  mount -a
fi

EnableRenderClient "${renderManager}" "${servicePassword}"

if [ "${teradiciLicenseKey}" != "" ]; then
  installType="pcoip-agent-license"
  installFile="/sbin/pcoip-register-host"
  ./$installFile --registration-code=${teradiciLicenseKey} 1> $installType.out.log 2> $installType.err.log
fi
