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

  az login --identity
  vmssState=$(az vmss show --resource-group ${wekaResourceGroupName} --name ${wekaVMScaleSetName} --query provisioningState --output tsv)
  if [ "$vmssState" == "Updating" ]; then
    joinIps=$(az vmss nic list --resource-group ${wekaResourceGroupName} --vmss-name ${wekaVMScaleSetName} --query [].ipConfigurations[0].privateIPAddress --output tsv | tr \\n ',')
    installType="weka-local-setup-drives"
    weka local setup container --name drives --base-port 14000 --join-ips $${joinIps::-1} --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends 1> $installType.out.log 2> $installType.err.log
    installType="weka-local-setup-compute"
    weka local setup container --name compute --base-port 15000 --join-ips $${joinIps::-1} --cores $coreCountCompute --compute-dedicated-cores $coreCountCompute --core-ids $coreIdsCompute --dedicate --memory $computeMemory --no-frontends 1> $installType.out.log 2> $installType.err.log
    installType="weka-local-setup-frontend"
    weka local setup container --name frontend --base-port 16000 --join-ips $${joinIps::-1} --cores $coreCountFrontend --frontend-dedicated-cores $coreCountFrontend --core-ids $coreIdsFrontend --dedicate 1> $installType.out.log 2> $installType.err.log
    weka user login admin ${wekaAdminPassword}
    nvmeDisks=/dev/nvme0n1
    for (( d=1; d<$(echo $machineSpec | jq -r .nvmeDisk); d++ )); do
      nvmeDisks="$nvmeDisks /dev/nvme$(echo $d)n1"
    done
    installType="weka-cluster-drives-add"
    containerId=$(weka cluster container --filter container=drives,ips=$(hostname -i) --output id --no-header)
    weka cluster drive add $containerId --HOST $(hostname) $nvmeDisks 1> $installType.out.log 2> $installType.err.log
    az network private-dns record-set a add-record --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --record-set-name ${dnsRecordSetName} --ipv4-address $(hostname -i)
  else
    installType="weka-local-setup-drives"
    weka local setup container --name drives --base-port 14000 --cores $coreCountDrives --drives-dedicated-cores $coreCountDrives --core-ids $coreIdsDrives --dedicate --no-frontends 1> $installType.out.log 2> $installType.err.log
  fi

  dataFilePath="/var/lib/waagent/ovf-env.xml"
  dataFileText=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $dataFilePath)
  codeFilePath="/usr/local/bin/terminate.sh"
  echo $dataFileText | base64 -d > $codeFilePath

  serviceFile="aaaEventHandler"
  serviceName="AAA Scheduled Event Handler"
  servicePath="/etc/systemd/system/$serviceFile.service"
  echo "[Unit]" > $servicePath
  echo "Description=$serviceName Service" >> $servicePath
  echo "After=network-online.target" >> $servicePath
  echo "" >> $servicePath
  echo "[Service]" >> $servicePath
  echo "ExecStart=/bin/bash $codeFilePath" >> $servicePath
  echo "" >> $servicePath
  timerPath="/etc/systemd/system/$serviceFile.timer"
  echo "[Unit]" > $timerPath
  echo "Description=$serviceName Timer" >> $timerPath
  echo "" >> $timerPath
  echo "[Timer]" >> $timerPath
  echo "OnUnitActiveSec=30" >> $timerPath
  echo "AccuracySec=1us" >> $timerPath
  echo "" >> $timerPath
  echo "[Install]" >> $timerPath
  echo "WantedBy=timers.target" >> $timerPath
  systemctl --now enable $serviceFile
fi
