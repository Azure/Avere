#!/bin/bash

set -ex

IFS=';' read -a fileSystemMounts <<< "${join(";", fileSystemMounts)}"
for fileSystemMount in "$${fileSystemMounts[@]}"
do
  IFS=' ' read -a fsTabMount <<< "$fileSystemMount"
  directoryPath="$${fsTabMount[1]}"
  mkdir -p $directoryPath
  echo $fileSystemMount >> /etc/fstab
done
mount -a
