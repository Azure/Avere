#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

%{ if teradiciLicenseKey != "" }
  pcoip-register-host --registration-code=${teradiciLicenseKey}
%{ endif }

%{ for fsMount in fileSystemMountsStorage }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
%{ for fsMount in fileSystemMountsStorageCache }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
%{ if renderManager == "RoyalRender" }
  %{ for fsMount in fileSystemMountsRoyalRender }
    fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
    mkdir -p $fsMountPoint
    echo "${fsMount}" >> /etc/fstab
  %{ endfor }
%{ endif }
%{ if renderManager == "Deadline" }
  %{ for fsMount in fileSystemMountsDeadline }
    fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
    mkdir -p $fsMountPoint
    echo "${fsMount}" >> /etc/fstab
  %{ endfor }
%{ endif }
mount -a
