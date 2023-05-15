#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

if [ "${wekaClusterName}" != "" ]; then
  dnf -y install kernel-devel-$(uname -r)

  volumeLabel="weka-iosw"
  installDisk="/dev/$(lsblk | grep ${wekaDataDiskSize}G | awk '{print $1}')"
  mkfs.ext4 -L $volumeLabel $installDisk &> weka-mkfs.log
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
  ./install.sh &> ../$volumeLabel.log
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

  fileSystemScript="${wekaFileSystemScript}"
  echo "fsName=${wekaFileSystemName}" > $fileSystemScript
  echo 'fsDriveCapacityBytes=$(weka status --json | jq -r .capacity.total_bytes)' >> $fileSystemScript
  echo 'fsTotalCapacityBytes=$(($fsDriveCapacityBytes * 100 / (100 - ${wekaObjectTierPercent})))' >> $fileSystemScript

  containerName="default"
  weka local stop --force $containerName
  weka local rm --force $containerName

  az login --identity
  failureDomain=$(hostname)
  drivesContainerName="drives0"
  vmScaleSetState=$(az vmss show --resource-group ${wekaResourceGroupName} --name ${wekaVMScaleSetName} --query provisioningState --output tsv)
  if [ "$vmScaleSetState" == "Updating" ]; then
    az network private-dns record-set a add-record --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --record-set-name ${dnsRecordSetName} --ipv4-address $(hostname -i)
    joinIps=$(az vmss nic list --resource-group ${wekaResourceGroupName} --vmss-name ${wekaVMScaleSetName} --query [].ipConfigurations[0].privateIPAddress --output tsv | tr \\n ',')
    weka local setup container --name $drivesContainerName --base-port 14000 --failure-domain $failureDomain --join-ips $${joinIps::-1} --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends &> weka-container-$drivesContainerName.log
    weka local setup container --name compute0 --base-port 15000 --failure-domain $failureDomain --join-ips $${joinIps::-1} --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $computeMemory --no-frontends &> weka-container-compute0.log
    weka local setup container --name frontend0 --base-port 16000 --failure-domain $failureDomain --join-ips $${joinIps::-1} --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate &> weka-container-frontend0.log
    weka user login admin ${wekaAdminPassword}
    nvmeDisks=/dev/nvme0n1
    for (( d=1; d<$(echo $machineSpec | jq -r .nvmeDisk); d++ )); do
      nvmeDisks="$nvmeDisks /dev/nvme$(echo $d)n1"
    done
    containerId=$(weka cluster container --filter container=$drivesContainerName,ips=$(hostname -i) --output id --no-header)
    weka cluster drive add $containerId --HOST $(hostname) $nvmeDisks &> weka-cluster-drive.log
    source $fileSystemScript
    weka fs update $fsName --ssd-capacity "$fsDriveCapacityBytes"B --total-capacity "$fsTotalCapacityBytes"B &> weka-fs-update.log
  else
    weka local setup container --name $drivesContainerName --base-port 14000 --failure-domain $failureDomain --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends &> weka-container-$drivesContainerName.log
  fi

  if [ $(hostname) == "${wekaClusterName}000000" ]; then
    systemctl --now enable nfs-server
    mkdir -p $binDirectory/log
    echo "$binDirectory/log *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -r
  fi

  dataFilePath="/var/lib/waagent/ovf-env.xml"
  dataFileText=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $dataFilePath)
  codeFilePath="$binDirectory/terminate.sh"
  echo $dataFileText | base64 -d > $codeFilePath
  chmod +x $codeFilePath

  if [ "${wekaTerminateNotification.enable}" == "true" ]; then
    cronFilePath="/tmp/crontab"
    echo "* * * * * $codeFilePath" > $cronFilePath
    crontab $cronFilePath
  fi
fi
