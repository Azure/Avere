#!/bin/bash -ex

source /etc/profile.d/aaa.sh

cd /usr/local/bin

functionsCode="functions.sh"
functionsData="${filebase64("../0.global/functions.sh")}"
echo $functionsData | base64 --decode > $functionsCode
source $functionsCode

SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
if [[ ${renderManager} == *Deadline* ]]; then
  AddMount "${fsMount.schedulerDeadline}"
fi
mount -a

EnableRenderClient "${renderManager}" "${servicePassword}"

servicePath="/etc/systemd/system/scheduledEventHandler.service"
echo "[Unit]" > $servicePath
echo "Description=AAA Scheduled Event Handler Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "ExecStart=/bin/bash /tmp/terminate.sh" >> $servicePath
echo "" >> $servicePath
timerPath="/etc/systemd/system/scheduledEventHandler.timer"
echo "[Unit]" > $timerPath
echo "Description=AAA Scheduled Event Handler Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnUnitActiveSec=${terminateNotificationDetectionIntervalSeconds}" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath
systemctl --now enable scheduledEventHandler
