#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

if [ "${wekaClusterName}" != "" ]; then
  installDisk="/dev/$(lsblk | grep ${wekaDataDiskSize}G | awk '{print $1}')"
  installType="weka-mkfs"
  volumeLabel="weka-iosw"
  mkfs.ext4 -L $volumeLabel $installDisk 1> $installType.out.log 2> $installType.err.log
  installPath="/opt/weka"
  mkdir -p $installPath
  installType="weka-mount"
  mount $installDisk $installPath 1> $installType.out.log 2> $installType.err.log
  echo "LABEL=$volumeLabel $installPath ext4 defaults 0 2" >> /etc/fstab

  dnf -y install kernel-devel-$(uname -r)
  versionInfo="4.1.0.77"
  installType="weka-iosw"
  installFile="weka-$versionInfo.tar"
  downloadUrl="${binStorageHost}/Weka/$versionInfo/$installFile${binStorageAuth}"
  curl -o $installFile -L $downloadUrl
  tar -xf $installFile
  cd weka-$versionInfo
  ./install.sh 1> ../$installType.out.log 2> ../$installType.err.log
  cd $binDirectory
fi
