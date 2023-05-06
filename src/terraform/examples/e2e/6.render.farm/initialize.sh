#!/bin/bash -ex

source /etc/profile.d/aaa.sh

cd /usr/local/bin

functionsCode="functions.sh"
functionsData="${filebase64("../0.global/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

if [ "${fsMount.enable}" == "true" ]; then
  SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
  if [[ ${renderManager} == *Deadline* ]]; then
    AddMount "${fsMount.schedulerDeadline}"
  fi
  mount -a
fi

EnableRenderClient "${renderManager}" "${servicePassword}"

serviceFile="aaaEventHandler"
serviceName="AAA Scheduled Event Handler"
servicePath="/etc/systemd/system/$serviceFile.service"
echo "[Unit]" > $servicePath
echo "Description=$serviceName Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "ExecStart=/bin/bash /tmp/terminate.sh" >> $servicePath
echo "" >> $servicePath
timerPath="/etc/systemd/system/$serviceFile.timer"
echo "[Unit]" > $timerPath
echo "Description=$serviceName Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnUnitActiveSec=${terminateNotificationDetectionIntervalSeconds}" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath
systemctl --now enable $serviceFile
