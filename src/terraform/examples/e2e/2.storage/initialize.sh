#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

if [ "${wekaResourceName}" != "" ]; then
  dnf -y install kernel-devel-$(uname -r)

  installDisk="/dev/$(lsblk | grep ${wekaDataDiskSize}G | awk '{print $1}')"
  installType="weka-mkfs"
  volumeLabel="weka-iosw"
  mkfs.ext4 -L $volumeLabel $installDisk 1> $installType.out.log 2> $installType.err.log
  installPath="/opt/weka"
  mkdir -p $installPath
  echo "LABEL=$volumeLabel $installPath ext4 defaults 0 2" >> /etc/fstab
  mount -a

  versionInfo="${wekaVersion}"
  installFile="weka-$versionInfo.tar"
  downloadUrl="${binStorageHost}/Weka/$versionInfo/$installFile${binStorageAuth}"
  curl -o $installFile -L $downloadUrl
  tar -xf $installFile
  cd weka-$versionInfo
  ./install.sh 1> ../$volumeLabel.out.log 2> ../$volumeLabel.err.log
  cd $binDirectory

  coreIdsScript="${wekaCoreIdsScript}"
  echo 'coreCountDrives=$(echo $machineSpec | jq -r .coreDrives)' > $coreIdsScript
  echo 'coreCountCompute=$(echo $machineSpec | jq -r .coreCompute)' >> $coreIdsScript
  echo 'coreCountFrontend=$(echo $machineSpec | jq -r .coreFrontend)' >> $coreIdsScript
  echo 'computeMemory=$(echo $machineSpec | jq -r .computeMemory)' >> $coreIdsScript
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
  echo 'coreIdsDrives=$(GetCoreIds $coreCountDrives 0)' >> $coreIdsScript
  echo 'coreIdsCompute=$(GetCoreIds $coreCountCompute $coreCountDrives)' >> $coreIdsScript
  echo 'coreIdsFrontend=$(GetCoreIds $coreCountFrontend $(($coreCountDrives + $coreCountCompute)))' >> $coreIdsScript

  machineSpec=${wekaMachineSpec}
  source $coreIdsScript

  containerName="default"
  weka local stop --force $containerName
  weka local rm --force $containerName

  installType="weka-local-setup-drives"
  weka local setup container --name drives --base-port 14000 --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends 1> $installType.out.log 2> $installType.err.log
fi
