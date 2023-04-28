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

  coreIdsScript="${wekaCoreIdsScript}"
  echo 'coreCountDrives=$(echo $containerSize | jq -r .coreDrives)' > $coreIdsScript
  echo 'coreCountCompute=$(echo $containerSize | jq -r .coreCompute)' >> $coreIdsScript
  echo 'coreCountFrontend=$(echo $containerSize | jq -r .coreFrontend)' >> $coreIdsScript
  echo 'memory=$(echo $containerSize | jq -r .memory)' >> $coreIdsScript
  echo '' >> $coreIdsScript
  echo 'coreIds="$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut --delimiter - --fields 1 | sort --unique | tr \\n -)"' >> $coreIdsScript
  echo 'coreIds="$${coreIds:2}"' >> $coreIdsScript
  echo 'IFS="-" read -a coreIds <<< "$coreIds"' >> $coreIdsScript
  echo '' >> $coreIdsScript
  echo 'function GetCoreIds {' >> $coreIdsScript
  echo '  coreCount=$1' >> $coreIdsScript
  echo '  coreIdStart=$2' >> $coreIdsScript
  echo '  coreIdEnd=$(($coreIdStart + $coreCount))' >> $coreIdsScript
  echo '  containerCoreIds=""' >> $coreIdsScript
  echo '  for (( i=$coreIdStart; i<$coreIdEnd; i++ )); do' >> $coreIdsScript
  echo '    if [ "$containerCoreIds" != "" ]; then' >> $coreIdsScript
  echo '      containerCoreIds="$containerCoreIds,"' >> $coreIdsScript
  echo '    fi' >> $coreIdsScript
  echo '    containerCoreIds="$containerCoreIds$${coreIds[i]}"' >> $coreIdsScript
  echo '  done' >> $coreIdsScript
  echo '  echo $containerCoreIds' >> $coreIdsScript
  echo '}' >> $coreIdsScript
  echo '' >> $coreIdsScript
  echo 'coreIdsDrive=$(GetCoreIds $coreCountDrives 0)' >> $coreIdsScript
  echo 'coreIdsCompute=$(GetCoreIds $coreCountCompute $coreCountDrives)' >> $coreIdsScript
  echo 'coreIdsFrontend=$(GetCoreIds $coreCountFrontend $(($coreCountDrives + $coreCountCompute)))' >> $coreIdsScript

  containerSize=${wekaContainerSize}
  source $coreIdsScript

  containerName="default"
  weka local stop --force $containerName
  weka local rm --force $containerName

  installType="weka-local-setup-drives"
  echo $coreIdsDrive > $installType-core-ids.log
  weka local setup container --name drives0 --base-port 14000 --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrive --dedicate --no-frontends 1> $installType.out.log 2> $installType.err.log

  installType="weka-local-setup-compute"
  echo $coreIdsCompute > $installType-core-ids.log
  weka local setup container --name compute0 --base-port 15000 --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $memory --no-frontends 1> $installType.out.log 2> $installType.err.log

  installType="weka-local-setup-frontend"
  echo $coreIdsFrontend > $installType-core-ids.log
  weka local setup container --name frontend0 --base-port 16000 --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate --allow-protocols true 1> $installType.out.log 2> $installType.err.log
fi
