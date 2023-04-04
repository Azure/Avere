#!/bin/bash -ex

source /etc/profile.d/aaa.sh

functionsFile="/usr/local/bin/functions.sh"
functionsCode="${ filebase64("../0.global/functions.sh") }"
echo $functionsCode | base64 --decode > $functionsFile
source $functionsFile

AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsRoyalRender) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
mount -a

if [ "${teradiciLicenseKey}" != "" ]; then
  pcoip-register-host --registration-code=${teradiciLicenseKey}
fi
