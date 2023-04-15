#!/bin/bash -ex

source /etc/profile.d/aaa.sh

cd "/usr/local/bin"

if [[ ${renderManager} == *RoyalRender* ]]; then
  installType="royal-render-server"
  serviceUser="rrService"
  useradd -r $serviceUser -p "${servicePassword}"
  rrServerconsole -initAndClose > $installType-init.log
  rrWorkstation_installer -serviceServer -rrUser $serviceUser -rrUserPW "${servicePassword}" 1> $installType-service.out.log 2> $installType-service.err.log
fi

if [ "${qubeLicense.userName}" != "" ]; then
  configFilePath="/etc/qube/dra.conf"
  sed -i "s/# mls_user =/mls_user = ${qubeLicense.userName}/" $configFilePath
  sed -i "s/# mls_password =/mls_password = ${qubeLicense.userPassword}/" $configFilePath
  systemctl restart dra.service
fi

serviceType="aaa-scale"
serviceName="AAA Auto Scale"

dataFilePath="/var/lib/waagent/ovf-env.xml"
dataFileText=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $dataFilePath)
codeFilePath="/var/lib/waagent/$serviceType.sh"
echo $dataFileText | base64 -d > $codeFilePath

servicePath="/etc/systemd/system/$serviceType.service"
echo "[Unit]" > $servicePath
echo "Description=$serviceName Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "Environment=scaleSetName=${autoScale.scaleSetName}" >> $servicePath
echo "Environment=resourceGroupName=${autoScale.resourceGroupName}" >> $servicePath
echo "Environment=jobWaitThresholdSeconds=${autoScale.jobWaitThresholdSeconds}" >> $servicePath
echo "ExecStart=/bin/bash $codeFilePath" >> $servicePath
echo "" >> $servicePath

timerPath="/etc/systemd/system/$serviceType.timer"
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
  systemctl --now enable $serviceType
fi
