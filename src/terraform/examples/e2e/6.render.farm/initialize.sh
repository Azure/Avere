#!/bin/bash -ex

source /etc/profile.d/aaa.sh

binDirectory="/usr/local/bin"
cd $binDirectory

functionsFile="$binDirectory/functions.sh"
functionsCode="${ filebase64("../0.global/functions.sh") }"
echo $functionsCode | base64 --decode > $functionsFile
source $functionsFile

AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsRoyalRender) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
mount -a

if [[ ${renderManager} == *RoyalRender* ]]; then
  installType="royal-render-client"
  serviceUser="rrService"
  useradd -r $serviceUser -p ${servicePassword}
  rrWorkstation_installer -service -rrUser $serviceUser -rrUserPW ${servicePassword} -fwOut 1> $installType-service.out.log 2> $installType-service.err.log
fi

servicePath="/etc/systemd/system/scheduledEventHandler.service"
echo "[Unit]" > $servicePath
echo "Description=AAA Scheduled Event Handler Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "ExecStart=/bin/bash /tmp/onTerminate.sh" >> $servicePath
echo "" >> $servicePath
timerPath="/etc/systemd/system/scheduledEventHandler.timer"
echo "[Unit]" > $timerPath
echo "Description=AAA Scheduled Event Handler Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnUnitActiveSec=${terminationNotificationDetectionIntervalSeconds}" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath
systemctl --now enable scheduledEventHandler
