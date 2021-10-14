#!/bin/bash

set -ex

IFS=';' read -a fileSystemMounts <<< "${join(";", fileSystemMounts)}"
for fileSystemMount in "$${fileSystemMounts[@]}"
do
  IFS=' ' read -a fsTabMount <<< "$fileSystemMount"
  directoryPath="$${fsTabMount[1]}"
  mkdir -p $directoryPath
  echo $fileSystemMount >> /etc/fstab
done
mount -a

if [ "$teradiciLicenseKey" != "" ]; then
  yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
  yum -y install epel-release
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
  pcoip-register-host --registration-code="$teradiciLicenseKey"
  systemctl restart 'pcoip-agent'
fi
