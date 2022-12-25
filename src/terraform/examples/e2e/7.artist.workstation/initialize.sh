#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

source /etc/profile.d/aaa.sh

functionsFile="$binDirectory/functions.sh"
functionsCode="${ filebase64("../0.global/functions.sh") }"
echo $functionsCode | base64 --decode > $functionsFile
source $functionsFile

%{ if teradiciLicenseKey != "" }
  pcoip-register-host --registration-code=${teradiciLicenseKey}
%{ endif }

AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsQube) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
mount -a
