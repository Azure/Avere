#!/bin/bash -ex

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

databaseHost=$(hostname)
databasePort=27100
databaseName="deadline10db"
deadlinecommand -UpdateDatabaseSettings /DeadlineRepository MongoDB $databaseHost $databaseName $databasePort 0 false false "" "" "" false
