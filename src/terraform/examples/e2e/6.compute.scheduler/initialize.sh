#!/bin/bash -ex

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

customDataInput="/var/lib/waagent/ovf-env.xml"
customDataOutput="/var/lib/waagent/scale.sh"
customData=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $customDataInput)
echo $customData | base64 -d | gzip -d > $customDataOutput

scaleServicePath="/etc/systemd/system/scale.service"
echo "[Unit]" > $scaleServicePath
echo "Description=Render Farm Scaler Service" >> $scaleServicePath
echo "" >> $scaleServicePath
echo "[Service]" >> $scaleServicePath
echo "Environment=PATH=$schedulerPath:$PATH" >> $scaleServicePath
echo "Environment=scaleSetName=${autoScale.scaleSetName}" >> $scaleServicePath
echo "Environment=resourceGroupName=${autoScale.resourceGroupName}" >> $scaleServicePath
echo "Environment=jobWaitThresholdSeconds=${autoScale.jobWaitThresholdSeconds}" >> $scaleServicePath
echo "Environment=workerIdleDeleteSeconds=${autoScale.workerIdleDeleteSeconds}" >> $scaleServicePath
echo "ExecStart=/bin/bash $customDataOutput" >> $scaleServicePath
echo "" >> $scaleServicePath
scaleTimerPath="/etc/systemd/system/scale.timer"
echo "[Unit]" > $scaleTimerPath
echo "Description=Render Farm Scaler Timer" >> $scaleTimerPath
echo "" >> $scaleTimerPath
echo "[Timer]" >> $scaleTimerPath
echo "OnBootSec=10" >> $scaleTimerPath
echo "OnUnitActiveSec=${autoScale.detectionIntervalSeconds}" >> $scaleTimerPath
echo "AccuracySec=1us" >> $scaleTimerPath
echo "" >> $scaleTimerPath
echo "[Install]" >> $scaleTimerPath
echo "WantedBy=timers.target" >> $scaleTimerPath

if [ ${autoScale.enable} == true ]; then
  systemctl --now enable scale.timer
fi

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

if [ ${cycleCloud.enable} == true ]; then
  cycleCloudPath="/etc/yum.repos.d/cyclecloud.repo"
  echo "[cyclecloud]" > $cycleCloudPath
  echo "name=cyclecloud" >> $cycleCloudPath
  echo "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud" >> $cycleCloudPath
  echo "gpgcheck=1" >> $cycleCloudPath
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $cycleCloudPath
  yum -y install cyclecloud8
fi
