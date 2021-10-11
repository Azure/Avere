#!/bin/bash

set -ex

yum -y install nfs-utils

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
lshw -class "display" | grep "Tesla M60" && nvV3=true || nvV3=false
if $nvV3; then
  yum -y install gcc
  yum -y install "kernel-devel-uname-r == $(uname -r)"
  fileName="nvidia-gpu.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -L -o $fileName $downloadUrl
  chmod +x $fileName
  ./$fileName -s
fi

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
lshw -class "display" | grep "Radeon Instinct MI25" && nvV4=true || nvV4=false
if $nvV4; then
  fileName="amd-gpu.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -L -o $fileName $downloadUrl
  tar -xJf $fileName
  cd amdgpu*
  fileName="amdgpu-pro-install"
  chmod +x $fileName
  ./$fileName -y --opencl=legacy.pal
fi

if ["$subnetName" == "Workstation"]; then
  yum -y groups install "GNOME Desktop"
fi
