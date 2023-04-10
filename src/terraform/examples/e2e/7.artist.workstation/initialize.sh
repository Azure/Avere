#!/bin/bash -ex

source /etc/profile.d/aaa.sh

cd "/usr/local/bin"

functionsCode="functions.sh"
functionsData="${filebase64("../0.global/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
if [[ ${renderManager} == *RoyalRender* ]]; then
  AddMount "${fsMount.schedulerRoyalRender}"
fi
if [[ ${renderManager} == *Deadline* ]]; then
  AddMount "${fsMount.schedulerDeadline}"
fi
mount -a

EnableRenderClient "${renderManager}" "${servicePassword}"

if [ "${teradiciLicenseKey}" != "" ]; then
  installType="pcoip-agent-license"
  installFile="/sbin/pcoip-register-host"
  ./$installFile --registration-code=${teradiciLicenseKey} 1> $installType.out.log 2> $installType.err.log
fi
