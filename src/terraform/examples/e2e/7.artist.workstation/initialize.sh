#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsFile="$binDirectory/functions.sh"
functionsCode="${ filebase64("../0.global/functions.sh") }"
echo $functionsCode | base64 --decode > $functionsFile
source $functionsFile

AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsRoyalRender) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
mount -a

if [[ ${renderManager} == *RoyalRender* ]]; then
  installType="royal-render-client"
  serviceUser="rrService"
  useradd -r $serviceUser -p "${servicePassword}"
  rrWorkstation_installer -plugins -service -rrUser $serviceUser -rrUserPW "${servicePassword}" -fwOut 1> $installType-service.out.log 2> $installType-service.err.log
fi

if [ "${teradiciLicenseKey}" != "" ]; then
  installType="pcoip-agent-license"
  installFile="/sbin/pcoip-register-host"
  ./$installFile --registration-code=${teradiciLicenseKey} 1> $installType.out.log 2> $installType.err.log
fi
