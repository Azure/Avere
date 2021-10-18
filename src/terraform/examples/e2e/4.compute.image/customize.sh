#!/bin/bash -ex

cd /usr/local/bin

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if [[ "$machineSize" == Standard_NV* && "$machineSize" == *_v3 ]]; then
  yum -y install gcc
  yum -y install "kernel-devel-uname-r == $(uname -r)"
  fileName="nvidia-gpu.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -L -o $fileName $downloadUrl
  chmod +x $fileName
  ./$fileName -s
fi

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if [[ "$machineSize" == Standard_NV* && "$machineSize" == *_v4 ]]; then
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

schedulerVersion="10.1.18.5"
schedulerLicense="LicenseFree"

fileName="Deadline-$schedulerVersion-linux-installers.tar"
curl -L -o $fileName "$storageContainerUrl/Deadline/$fileName$storageContainerSas"
tar -xf $fileName

if [[ "$machineSize" == Standard_L* ]]; then
  fileName="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
  ./$fileName --mode unattended --licensemode $schedulerLicense --dbLicenseAcceptance accept --installmongodb true
else
  yum -y install libXi
  yum -y install libXxf86vm
  yum -y install libXfixes
  yum -y install libXrender
  yum -y install libGL
  fileName="blender-2.93.5-linux-x64.tar.xz"
  curl -L -o $fileName "$storageContainerUrl/Blender/$fileName$storageContainerSas"
  tar -xJf $fileName
  mv blender*/* .
fi

fileName="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
./$fileName --mode unattended --licensemode $schedulerLicense

if [ "$subnetName" == "Workstation" ]; then
  yum -y groups install "KDE Plasma Workspaces"
  fileName="teradici-pcoip-agent_rpm.sh"
  curl -L -o $fileName "$storageContainerUrl/Teradici/$fileName$storageContainerSas"
  cat $fileName | /bin/bash
  yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm
  yum -y install epel-release
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
fi
