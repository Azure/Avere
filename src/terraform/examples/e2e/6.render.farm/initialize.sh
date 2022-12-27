#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

source /etc/profile.d/aaa.sh

functionsFile="$binDirectory/functions.sh"
functionsCode="${ filebase64("../0.global/functions.sh") }"
echo $functionsCode | base64 --decode > $functionsFile
source $functionsFile

AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsQube) }"
AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
mount -a

%{ for fsPermission in fileSystemPermissions }
  ${fsPermission}
%{ endfor }

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
