#!/bin/bash -ex

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

%{ if teradiciLicenseKey != "" }
  pcoip-register-host --registration-code=${teradiciLicenseKey}
%{ endif }

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

# filePath="/mnt/show/$(hostname).txt"
# echo "AAA" > $filePath
# cat $filePath
