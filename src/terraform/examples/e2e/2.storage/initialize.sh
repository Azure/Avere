#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

if [ "${wekaAuthToken}" != "" ]; then
  osDisk="/dev/sdc"
  installType="weka-mkfs"
  volumeLabel="weka-iosw"
  mkfs.ext4 -L $volumeLabel $osDisk 1> $installType.out.log 2> $installType.err.log
  installPath="/opt/weka"
  mkdir -p $installPath
  installType="weka-mount"
  mount $osDisk $installPath 1> $installType.out.log 2> $installType.err.log
  echo "LABEL=$volumeLabel $installPath ext4 defaults 0 2" >> /etc/fstab

  versionInfo="4.1.0.77"
  installType="weka-iosw"
  curl https://${wekaAuthToken}@get.prod.weka.io/dist/v1/install/$wekaVersion/$wekaVersion | sh 1> $installType.out.log 2> $installType.err.log
fi
