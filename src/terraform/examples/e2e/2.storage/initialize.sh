#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

if [ "${wekaResourceName}" != "" ]; then
  installDisk="/dev/$(lsblk | grep ${wekaDataDiskSize}G | awk '{print $1}')"
  installType="weka-mkfs"
  volumeLabel="weka-iosw"
  mkfs.ext4 -L $volumeLabel $installDisk 1> $installType.out.log 2> $installType.err.log
  installPath="/opt/weka"
  mkdir -p $installPath
  echo "LABEL=$volumeLabel $installPath ext4 defaults 0 2" >> /etc/fstab
  mount -a

  dnf -y install kernel-devel-$(uname -r)
  versionInfo="${wekaVersion}"
  installType="weka-iosw"
  installFile="weka-$versionInfo.tar"
  downloadUrl="${binStorageHost}/Weka/$versionInfo/$installFile${binStorageAuth}"
  curl -o $installFile -L $downloadUrl
  tar -xf $installFile
  cd weka-$versionInfo
  ./install.sh 1> ../$installType.out.log 2> ../$installType.err.log
  cd $binDirectory

  containerName="default"
  weka local stop --force $containerName
  weka local rm --force $containerName

  containerSize=${wekaContainerSize}
  coreCountDrives=$(echo $containerSize | jq -r .coreDrives)
  coreCountCompute=$(echo $containerSize | jq -r .coreCompute)
  coreCountFrontend=$(echo $containerSize | jq -r .coreFrontend)
  memoryCompute=$(echo $containerSize | jq -r .memory)

  coreIds="$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -d '-' -f 1 | sort -u | tr '\n' ' ')"
  coreIds="$${coreIds:2}"
  IFS=", " read -ra coreIds <<< "$coreIds"

  function GetCoreIds {
    coreCount=$1
    coreIdStart=$2
    coreIdEnd=$(($coreIdStart + $coreCount))
    containerCoreIds=""
    for (( i=$coreIdStart; i<$coreIdEnd; i++ )); do
      if [ "$containerCoreIds" != "" ]; then
        containerCoreIds="$containerCoreIds,"
      fi
      containerCoreIds="$containerCoreIds$${coreIds[i]}"
    done
    echo $containerCoreIds
  }

  coreIdsDrive=$(GetCoreIds $coreCountDrives 0)
  coreIdsCompute=$(GetCoreIds $coreCountCompute $coreCountDrives)
  coreIdsFrontend=$(GetCoreIds $coreCountFrontend $(($coreCountDrives + $coreCountCompute)))

  installType="weka-local-setup-drives"
  echo $coreIdsDrive > $installType-core-ids.log
  weka local setup container --name drives0 --base-port 14000 --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrive --no-frontends --dedicate 1> $installType.out.log 2> $installType.err.log

  installType="weka-local-setup-compute"
  echo $coreIdsCompute > $installType-core-ids.log
  weka local setup container --name compute0 --base-port 15000 --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --no-frontends --dedicate --memory $memoryCompute 1> $installType.out.log 2> $installType.err.log

  installType="weka-local-setup-frontend"
  echo $coreIdsFrontend > $installType-core-ids.log
  weka local setup container --name frontend0 --base-port 16000 --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --allow-protocols true --dedicate 1> $installType.out.log 2> $installType.err.log
fi
