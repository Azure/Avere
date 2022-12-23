#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

servicePath="/etc/systemd/system/scheduledEventHandler.service"
echo "[Unit]" > $servicePath
echo "Description=Scheduled Event Handler Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "ExecStart=/bin/bash /tmp/onTerminate.sh" >> $servicePath
echo "" >> $servicePath
timerPath="/etc/systemd/system/scheduledEventHandler.timer"
echo "[Unit]" > $timerPath
echo "Description=Scheduled Event Handler Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnUnitActiveSec=${terminationNotificationDetectionIntervalSeconds}" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath
systemctl --now enable scheduledEventHandler

%{ for fsMount in fileSystemMountsStorage }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
%{ for fsMount in fileSystemMountsStorageCache }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
%{ for fsMount in fileSystemMountsQube }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
%{ for fsMount in fileSystemMountsDeadline }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

%{ for fsPermission in fileSystemPermissions }
  ${fsPermission}
%{ endfor }
