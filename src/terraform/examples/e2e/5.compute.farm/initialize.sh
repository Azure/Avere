#!/bin/bash

set -ex

mkdir -p $directoryPath

# IFS=';' read -a fileSystemMounts <<< "${join(";", fileSystemMounts)}"
# for fileSystemMount in "$${fileSystemMounts[@]}"
# do
#     IFS=' ' read -a fsTabMount <<< "$fileSystemMount"
#     directoryPath="$${fsTabMount[1]}"
#     mkdir -p $directoryPath
#     echo $fileSystemMount >> /etc/fstab
# done
# for i in {1..10}; do
#     mount -a
#     if [ $? -eq 0 ]; then
#         break
#     fi
#     sleep 1
# done
