#!/bin/bash -ex

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

servicePath="/etc/systemd/system/terminate.service"
echo "[Unit]" > $servicePath
echo "Description=Scheduled Event Handler Service" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=PATH=$schedulerPath:$PATH" >> $servicePath
echo "ExecStart=/bin/bash /tmp/terminate.sh" >> $servicePath
echo "" >> $servicePath
timerPath="/etc/systemd/system/terminate.timer"
echo "[Unit]" > $timerPath
echo "Description=Scheduled Event Handler Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnBootSec=10" >> $timerPath
echo "OnUnitActiveSec=5" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath
systemctl --now enable terminate.timer

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a
%{ for fsPermission in fileSystemPermissions }
  ${fsPermission}
%{ endfor }
