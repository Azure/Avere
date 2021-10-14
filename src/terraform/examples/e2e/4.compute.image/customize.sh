#!/bin/bash

set -ex

cd /usr/local/bin

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if [[ "$sizeSku" == Standard_NV* && "$sizeSku" == *_v3 ]]; then
  yum -y install gcc
  yum -y install "kernel-devel-uname-r == $(uname -r)"
  fileName="nvidia-gpu.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -L -o $fileName $downloadUrl
  chmod +x $fileName
  ./$fileName -s
fi

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if [[ "$sizeSku" == Standard_NV* && "$sizeSku" == *_v4 ]]; then
  fileName="amd-gpu.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -L -o $fileName $downloadUrl
  tar -xJf $fileName
  cd amdgpu*
  fileName="amdgpu-pro-install"
  chmod +x $fileName
  ./$fileName -y --opencl=legacy.pal
fi

yum -y install nfs-utils

storageContainerUrl="https://az0.blob.core.windows.net/bin"
storageContainerSas="?sp=r&sr=c&sig=Ysr0iLGUhilzRYPHuY066aZ69iT46uTx87pP2V%2BdMEY%3D&sv=2020-08-04&se=2222-12-31T00%3A00%3A00Z"

fileName="Deadline-10.1.18.5-linux-installers.tar"
curl -L -o $fileName "$storageContainerUrl/Deadline/$fileName$storageContainerSas"
tar -xf $fileName

fileName="Autodesk_Maya_2022_1_ML_Linux_64bit.tgz"
curl -L -o $fileName "$storageContainerUrl/Maya/$fileName$storageContainerSas"
tar -xzf $fileName

if ["$subnetName" == "Workstation"]; then
  yum -y groups install "GNOME Desktop"
  fileName="teradici-pcoip-agent_rpm.sh"
  curl -L -o $fileName "$storageContainerUrl/Teradici/$fileName$storageContainerSas"
  cat $fileName | /bin/bash
fi
