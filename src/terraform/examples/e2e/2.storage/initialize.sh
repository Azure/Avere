#!/bin/bash -ex

serviceType="aaa-install"
serviceName="AAA Storage Install"

customData="/var/lib/waagent/ovf-env.xml"
customCode=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $customData)
scriptFile="/var/lib/waagent/$serviceType.sh"
echo $customCode | base64 -d > $scriptFile

servicePath="/etc/systemd/system/$serviceType.service"
echo "[Unit]" > $servicePath
echo "Description=$serviceName Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=binStorageHost=${binStorageHost}" >> $servicePath
echo "Environment=binStorageAuth=${binStorageAuth}" >> $servicePath
echo "Environment=wekaClusterName=${wekaClusterName}" >> $servicePath
echo "ExecStart=/bin/bash $scriptFile" >> $servicePath
echo "" >> $servicePath

timerPath="/etc/systemd/system/$serviceType.timer"
echo "[Unit]" > $timerPath
echo "Description=$serviceName Timer" >> $servicePath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnStartupSec=10" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath

systemctl enable $serviceType
dnf -y upgrade --refresh
reboot
