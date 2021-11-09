#!/bin/bash -ex

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

hostName=$(hostname)
databasePort=27100
databaseName="deadline10db"

cd /opt/Thinkbox/Deadline10/bin/
./deadlinecommand -ConfigureDatabase $hostName $databasePort $databaseName false "" "" false ${userName} "pass:${userPassword}" "" false
./deadlinecommand -UpdateDatabaseSettings "/DeadlineRepository" "MongoDB" $hostName $databaseName $databasePort 0 false false ${userName} "pass:${userPassword}" "" false
./deadlinecommand -ChangeRepository "Direct" "/mnt/scheduler" "" ""
