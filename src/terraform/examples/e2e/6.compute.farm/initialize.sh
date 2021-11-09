#!/bin/bash -ex

%{ for fsMount in fileSystemMounts }
  fsMountPoint=$(cut -d ' ' -f 2 <<< "${fsMount}")
  mkdir -p $fsMountPoint
  echo "${fsMount}" >> /etc/fstab
%{ endfor }
mount -a

cd /opt/Thinkbox/Deadline10/bin/
./deadlinecommand -ChangeRepository "Direct" "/mnt/scheduler" "" ""
