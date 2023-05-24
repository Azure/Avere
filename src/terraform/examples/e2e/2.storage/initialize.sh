#!/bin/bash -ex

cd ${binDirectory}

if [ "${wekaClusterName}" != "" ]; then
  volumeLabel="weka-iosw"
  installDisk="/dev/$(lsblk | grep ${wekaDataDiskSize}G | awk '{print $1}')"
  mkfs.ext4 -L $volumeLabel $installDisk 2>&1 | tee weka-mkfs.log
  installPath="/opt/weka"
  mkdir -p $installPath
  echo "LABEL=$volumeLabel $installPath ext4 defaults 0 2" >> /etc/fstab
  mount -a

  curl https://${wekaApiToken}@get.weka.io/dist/v1/install/${wekaVersion}/${wekaVersion} | sh

  coreIdsScript=${wekaCoreIdsScript}
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

  driveDisksScript=${wekaDriveDisksScript}
  echo 'nvmeDisks=/dev/nvme0n1' > $driveDisksScript
  echo 'for (( d=1; d<$(echo $machineSpec | jq -r .nvmeDisk); d++ )); do' >> $driveDisksScript
  echo '  nvmeDisks="$nvmeDisks /dev/nvme$(echo $d)n1"' >> $driveDisksScript
  echo 'done' >> $driveDisksScript

  fileSystemScript=${wekaFileSystemScript}
  echo "fileSystemName=${wekaFileSystemName}" > $fileSystemScript
  echo 'fileSystemDriveBytes=$(weka status --json | jq -r .capacity.total_bytes)' >> $fileSystemScript
  echo 'fileSystemTotalBytes=$(echo "$fileSystemDriveBytes * 100 / (100 - ${wekaObjectTierPercent})" | bc)' >> $fileSystemScript

  containerName="default"
  weka local stop --force $containerName
  weka local rm --force $containerName

  az login --identity
  failureDomain=$(hostname)
  drivesContainerName=drives0
  vmScaleSetState=$(az vmss show --resource-group ${wekaResourceGroupName} --name ${wekaClusterName} --query provisioningState --output tsv)
  if [ "$vmScaleSetState" == Updating ]; then
    joinIps=$(az vmss nic list --resource-group ${wekaResourceGroupName} --vmss-name ${wekaClusterName} --query [].ipConfigurations[0].privateIPAddress --output tsv | tr \\n ',')
    weka local setup container --name $drivesContainerName --base-port 14000 --failure-domain $failureDomain --join-ips $${joinIps::-1} --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends &> weka-container-setup-$drivesContainerName.log
    weka local setup container --name compute0 --base-port 15000 --failure-domain $failureDomain --join-ips $${joinIps::-1} --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $computeMemory --no-frontends &> weka-container-setup-compute0.log
    weka local setup container --name frontend0 --base-port 16000 --failure-domain $failureDomain --join-ips $${joinIps::-1} --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate &> weka-container-setup-frontend0.log
    weka user login admin ${wekaAdminPassword}
    source $driveDisksScript
    containerId=$(weka cluster container --filter container=$drivesContainerName,ips=$(hostname -i) --output id --no-header)
    weka cluster drive add $containerId $nvmeDisks &> weka-cluster-drive-add.log
    if [ ${wekaFileSystemAutoScale} == true ]; then
      source $fileSystemScript
      weka fs update $fileSystemName --ssd-capacity "$fileSystemDriveBytes"B --total-capacity "$fileSystemTotalBytes"B &> weka-fs-update.log
    fi
    dnsRecordQuery="aRecords[?ipv4Address=='$(hostname -i)']"
    while [ -z "$dnsRecordAddress" ]; do
      az network private-dns record-set a add-record --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --record-set-name ${dnsRecordSetName} --ipv4-address $(hostname -i)
      sleep 5s
      dnsRecordAddress=$(az network private-dns record-set a show --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --name ${dnsRecordSetName} --query $dnsRecordQuery --output tsv)
    done
  else
    weka local setup container --name $drivesContainerName --base-port 14000 --failure-domain $failureDomain --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends &> weka-container-setup-$drivesContainerName.log
  fi

  if [ $(hostname) == ${wekaClusterName}000000 ]; then
    systemctl --now enable nfs-server
    mkdir -p ${binDirectory}/log
    echo "${binDirectory}/log *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -r
  fi

  dataFilePath="/var/lib/waagent/ovf-env.xml"
  dataFileText=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $dataFilePath)
  codeFilePath="${binDirectory}/terminate.sh"
  echo $dataFileText | base64 -d > $codeFilePath
  chmod +x $codeFilePath

  if [ ${wekaTerminateNotification.enable} == true ]; then
    cronFilePath="/tmp/crontab"
    echo "* * * * * $codeFilePath" > $cronFilePath
    crontab $cronFilePath
  fi
fi
