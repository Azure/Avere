#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

useradd --system --password ${serviceAccountPassword} ${serviceAccountName}

if [[ ${renderManager} == *RoyalRender* ]]; then
  installType="royal-render-server"
  rrServerconsole -initAndClose 2>&1 | tee $installType-init.log
  rrWorkstation_installer -serviceServer -rrUser ${serviceAccountName} -rrUserPW ${serviceAccountPassword} 2>&1 | tee $installType-service.log
fi

if [ "${qubeLicense.userName}" != "" ]; then
  configFilePath="/etc/qube/dra.conf"
  sed -i "s/# mls_user =/mls_user = ${qubeLicense.userName}/" $configFilePath
  sed -i "s/# mls_password =/mls_password = ${qubeLicense.userPassword}/" $configFilePath
  systemctl restart dra.service
fi

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
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "Environment=resourceGroupName=${autoScale.resourceGroupName}" >> $servicePath
echo "Environment=scaleSetName=${autoScale.scaleSetName}" >> $servicePath
echo "Environment=scaleSetMachineCountMax=${autoScale.scaleSetMachineCountMax}" >> $servicePath
echo "Environment=jobWaitThresholdSeconds=${autoScale.jobWaitThresholdSeconds}" >> $servicePath
echo "Environment=workerIdleDeleteSeconds=${autoScale.workerIdleDeleteSeconds}" >> $servicePath
echo "ExecStart=/bin/bash $codeFilePath" >> $servicePath
echo "" >> $servicePath

timerPath="/etc/systemd/system/$serviceFile.timer"
echo "[Unit]" > $timerPath
echo "Description=$serviceName Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnUnitActiveSec=${autoScale.detectionIntervalSeconds}" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath

if [ ${autoScale.enable} == true ]; then
  systemctl --now enable $serviceFile
fi
