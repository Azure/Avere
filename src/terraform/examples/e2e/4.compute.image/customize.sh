#!/bin/bash -ex

cd /usr/local

#   NVv3 - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
# NCT4v3 - https://docs.microsoft.com/en-us/azure/virtual-machines/nct4-v3-series
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

# NVv4 - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
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

echo "Customize (Start): Utilities"
yum -y install nfs-utils
yum -y install epel-release
yum -y install jq
echo "Customize (End): Utilities"

storageContainerUrl="https://az0.blob.core.windows.net/bin"
storageContainerSas="?sv=2020-08-04&st=2021-11-07T18%3A19%3A06Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=b4TcohYc%2FInzvG%2FQSxApyIaZlLT8Cl8ychUqZx6zNsg%3D"

schedulerVersion="10.1.20.2"
schedulerLicense="LicenseFree"
schedulerDatabasePath="/DeadlineDatabase"
schedulerRepositoryPath="/DeadlineRepository"

rendererVersion="3.0.0"

schedulerPath="/opt/Thinkbox/Deadline10/bin"
rendererPath="/usr/local/Blender"
profilePath="/etc/profile.d/aaa.sh"
if [ $subnetName == "Scheduler" ]; then
  echo "PATH=$PATH:$schedulerPath" >> $profilePath
else
  echo "PATH=$PATH:$schedulerPath:$rendererPath" >> $profilePath
fi

echo "Customize (Start): Deadline Download"
fileName="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$fileName$storageContainerSas"
curl -L -o $fileName $downloadUrl
tar -xf $fileName
echo "Customize (End): Deadline Download"

echo "Customize (Start): Deadline Client"
fileName="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
if [ $subnetName == "Scheduler" ]; then
  clientArgs="--slavestartup false --launcherdaemon false"
else
  useradd $userName
  [ $subnetName == "Farm" ] && workerStartup=true || workerStartup=false
  clientArgs="--slavestartup $workerStartup --launcherdaemon true --daemonuser $userName"
fi
./$fileName --mode unattended --licensemode $schedulerLicense $clientArgs
$schedulerPath/deadlinecommand -ChangeRepositorySkipValidation Direct /mnt/scheduler
$schedulerPath/deadlinecommand -ChangeLicenseMode $schedulerLicense
echo "Customize (End): Deadline Client"

if [ $subnetName == "Scheduler" ]; then
  echo "Customize (Start): Deadline Repository"
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
  fileName="blender-$rendererVersion-linux-x64.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$rendererVersion/$fileName$storageContainerSas"
  curl -L -o $fileName $downloadUrl
  tar -xJf $fileName
  mkdir Blender
  cd blender*
  mv * ../Blender
  echo "Customize (End): Blender"
fi

if [ $subnetName == "Workstation" ]; then
  echo "Customize (Start): Workstation Desktop"
  yum -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

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
