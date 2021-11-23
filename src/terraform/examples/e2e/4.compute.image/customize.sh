#!/bin/bash -ex

cd /usr/local/bin

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if [[ ($machineSize == Standard_NV* && $machineSize == *_v3) ||
      ($machineSize == Standard_NC* && $machineSize == *T4_v3) ]]; then
  echo "Customize (Start): GPU Driver (NVv3)"
  yum -y install gcc
  yum -y install "kernel-devel-uname-r == $(uname -r)"
  fileName="nvidia-gpu.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -L -o $fileName $downloadUrl
  chmod +x $fileName
  ./$fileName --silent
  echo "Customize (End): GPU Driver (NVv3)"
fi

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if [[ $machineSize == Standard_NV* && $machineSize == *_v4 ]]; then
  echo "Customize (Start): GPU Driver (NVv4)"
  fileName="amd-gpu.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -L -o $fileName $downloadUrl
  tar -xJf $fileName
  cd amdgpu*
  fileName="amdgpu-pro-install"
  ./$fileName -y --opencl=legacy,pal
  cd ..
  echo "Customize (End): GPU Driver (NVv4)"
fi

echo "Customize (Start): NFS Utilities"
yum -y install nfs-utils
echo "Customize (End): NFS Utilities"

echo "Customize (Start): CLI Tools"
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
yum -y install azure-cli
yum -y install epel-release
yum -y install jq
echo "Customize (End): CLI Tools"

storageContainerUrl="https://az0.blob.core.windows.net/bin"
storageContainerSas="?sv=2020-08-04&st=2021-11-07T18%3A19%3A06Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=b4TcohYc%2FInzvG%2FQSxApyIaZlLT8Cl8ychUqZx6zNsg%3D"

schedulerVersion="10.1.19.4"
schedulerLicense="LicenseFree"
schedulerDatabasePath="/DeadlineDatabase"
schedulerRepositoryPath="/DeadlineRepository"
blenderPath="/usr/local/bin"

fileName="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$fileName$storageContainerSas"
curl -L -o $fileName $downloadUrl
tar -xf $fileName

if [ "$subnetName" == "Scheduler" ]; then
  echo "Customize (Start): Deadline Repository"
  hostnamectl set-hostname scheduler
  fileName="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
  ./$fileName --mode unattended --dbLicenseAcceptance accept --installmongodb true --prefix $schedulerRepositoryPath --mongodir $schedulerDatabasePath --dbuser $userName --dbpassword $userPassword --requireSSL false
  systemctl start nfs-server
  systemctl enable nfs-server
  echo "$schedulerRepositoryPath *(rw,no_root_squash)" >> /etc/exports
  exportfs -a
  echo "Customize (End): Deadline Repository"
else
  echo "Customize (Start): Blender"
  yum -y install libXi
  yum -y install libXxf86vm
  yum -y install libXfixes
  yum -y install libXrender
  yum -y install libGL
  fileName="blender-2.93.6-linux-x64.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$fileName$storageContainerSas"
  curl -L -o $fileName $downloadUrl
  tar -xJf $fileName
  mv blender*/* .
  echo "Customize (End): Blender"
fi

if [ "$subnetName" == "Farm" ]; then
  echo "Customize (Start): Metadata Service"
  echo "* * * * * /tmp/preempt.sh" >> /etc/crontab
  echo "* * * * * sleep 30; /tmp/preempt.sh" >> /etc/crontab
  echo "Customize (End): Metadata Service"
fi

echo "Customize (Start): Deadline Client"
fileName="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
./$fileName --mode unattended --licensemode $schedulerLicense
echo "Customize (End): Deadline Client"

if [ "$subnetName" == "Workstation" ]; then
  echo "Customize (Start): Workstation Desktop"
  yum -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

  echo "Customize (Start): Blender Deadline Submitter"
  fileName="Blender-submitter-linux-x64-installer.run"
  downloadUrl="$storageContainerUrl/Deadline/Blender/Installers/$fileName$storageContainerSas"
  curl -L -o $fileName $downloadUrl
  chmod +x $fileName
  ./$fileName --mode unattended --source bundle --deadline_dir x --blender_dir $blenderPath
  echo "Customize (End): Blender Deadline Submitter"

  echo "Customize (Start): Teradici PCoIP Agent"
  fileName="teradici-pcoip-agent_rpm.sh"
  downloadUrl="$storageContainerUrl/Teradici/$fileName$storageContainerSas"
  curl -L -o $fileName $downloadUrl
  cat $fileName | /bin/bash
  yum -y install epel-release
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
  echo "Customize (End): Teradici PCoIP Agent"
fi

cp --recursive /tmp tmp
