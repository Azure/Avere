#!/bin/bash -x

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

serviceFile="aaaAutoScaler"
dataFilePath="/var/lib/waagent/ovf-env.xml"
dataFileText=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $dataFilePath)
codeFilePath="$binDirectory/$serviceFile.sh"
echo $dataFileText | base64 -d > $codeFilePath
chmod +x $codeFilePath

serviceName="AAA Auto Scaler"
servicePath="/etc/systemd/system/$serviceFile.service"
echo "[Unit]" > $servicePath
echo "Description=$serviceName Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=resourceGroupName=${autoScale.resourceGroupName}" >> $servicePath
echo "Environment=scaleSetName=${autoScale.scaleSetName}" >> $servicePath
echo "Environment=scaleSetMachineCountMax=${autoScale.scaleSetMachineCountMax}" >> $servicePath
echo "Environment=jobWaitThresholdSeconds=${autoScale.jobWaitThresholdSeconds}" >> $servicePath
echo "Environment=workerIdleDeleteSeconds=${autoScale.workerIdleDeleteSeconds}" >> $servicePath
echo "ExecStart=/bin/bash $codeFilePath" >> $servicePath
echo "" >> $servicePath

serviceTimerPath="/etc/systemd/system/$serviceFile.timer"
echo "[Unit]" > $serviceTimerPath
echo "Description=$serviceName Timer" >> $serviceTimerPath
echo "" >> $serviceTimerPath
echo "[Timer]" >> $serviceTimerPath
echo "OnUnitActiveSec=${autoScale.detectionIntervalSeconds}" >> $serviceTimerPath
echo "AccuracySec=1us" >> $serviceTimerPath
echo "" >> $serviceTimerPath
echo "[Install]" >> $serviceTimerPath
echo "WantedBy=timers.target" >> $serviceTimerPath

if [ ${autoScale.enable} == true ]; then
  systemctl --now enable $serviceFile
fi
