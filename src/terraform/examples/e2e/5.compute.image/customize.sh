#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

#   NVv3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nct4-v3-series)
if [[ ($machineSize == Standard_NV* && $machineSize == *_v3) ||
      ($machineSize == Standard_NC* && $machineSize == *T4_v3) ]]; then
  echo "Customize (Start): GPU Driver (NVv3)"
  yum -y install gcc
  yum -y install "kernel-devel-$(uname --kernel-release)"
  installFile="nvidia-gpu-nv3.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -L -o $installFile $downloadUrl
  chmod +x $installFile
  ./$installFile --silent &> $installFile.txt
  echo "Customize (End): GPU Driver (NVv3)"
fi

# NVv4 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series)
if [[ $machineSize == Standard_NV* && $machineSize == *_v4 ]]; then
  echo "Customize (Start): GPU Driver (NVv4)"
  installFile="amd-gpu-nv4.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -L -o $installFile $downloadUrl
  tar -xJf $installFile
  cd amdgpu*
  installFile="amdgpu-pro-install"
  ./$installFile -y --opencl=legacy,pal &> $installFile.txt
  cd $binDirectory
  echo "Customize (End): GPU Driver (NVv4)"
fi

# NVv5 (https://docs.microsoft.com/en-us/azure/virtual-machines/nva10v5-series)
if [[ $machineSize == Standard_NV* && $machineSize == *_v5 ]]; then
  echo "Customize (Start): GPU Driver (NVv5)"
  yum -y install gcc
  yum -y install "kernel-devel-$(uname --kernel-release)"
  installFile="nvidia-gpu-nv5.run"
  downloadUrl="https://download.microsoft.com/download/4/3/9/439aea00-a02d-4875-8712-d1ab46cf6a73/NVIDIA-Linux-x86_64-510.47.03-grid-azure.run"
  curl -L -o $installFile $downloadUrl
  chmod +x $installFile
  ./$installFile --silent &> $installFile.txt
  echo "Customize (End): GPU Driver (NVv5)"
fi

echo "Customize (Start): Core Utilities"
yum -y install nfs-utils
yum -y install epel-release
yum -y install jq
echo "Customize (End): Core Utilities"

if [ $subnetName == "Scheduler" ]; then
  echo "Customize (Start): NFS Server"
  systemctl --now enable nfs-server
  echo "Customize (End): NFS Server"

  echo "Customize (Start): Azure CLI"
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  repoFile="/etc/yum.repos.d/azure-cli.repo"
  echo "[azure-cli]" > $repoFile
  echo "name=AzureCLI" >> $repoFile
  echo "baseurl=https://packages.microsoft.com/yumrepos/azure-cli" >> $repoFile
  echo "enabled=1" >> $repoFile
  echo "gpgcheck=1" >> $repoFile
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $repoFile
  yum -y install azure-cli
  echo "Customize (End): Azure CLI"
fi

storageContainerUrl="https://az0.blob.core.windows.net/bin"
storageContainerSas="?sv=2020-08-04&st=2021-11-07T18%3A19%3A06Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=b4TcohYc%2FInzvG%2FQSxApyIaZlLT8Cl8ychUqZx6zNsg%3D"

schedulerVersion="10.1.20.2"
schedulerLicense="LicenseFree"
schedulerDatabasePath="/DeadlineDatabase"
schedulerRepositoryPath="/DeadlineRepository"
schedulerCertificateFile="Deadline10Client.pfx"
schedulerRepositoryLocalMount="/mnt/scheduler"
schedulerRepositoryCertificate="$schedulerRepositoryLocalMount/$schedulerCertificateFile"

rendererPaths=""
schedulerPath="/opt/Thinkbox/Deadline10/bin"
rendererPathMaya="/usr/autodesk/maya2022/bin"
rendererPathNuke="/usr/local/nuke13"
rendererPathUnreal="/usr/local/unreal5"
rendererPathBlender="/usr/local/blender3"
if [[ $renderEngines == *Maya* ]]; then
  rendererPaths="$rendererPaths:$rendererPathMaya"
fi
if [[ $renderEngines == *Nuke* ]]; then
  rendererPaths="$rendererPaths:$rendererPathNuke"
fi
if [[ $renderEngines == *Unreal* ]]; then
  rendererPaths="$rendererPaths:$rendererPathUnreal"
fi
if [[ $renderEngines == *Blender* ]]; then
  rendererPaths="$rendererPaths:$rendererPathBlender"
fi
echo "PATH=$PATH:$schedulerPath$rendererPaths" >> /etc/profile.d/aaa.sh

echo "Customize (Start): Deadline Download"
installFile="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
curl -L -o $installFile $downloadUrl
tar -xf $installFile
echo "Customize (End): Deadline Download"

if [ $subnetName == "Scheduler" ]; then
  echo "Customize (Start): Deadline Repository"
  installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
  ./$installFile --mode unattended --dbLicenseAcceptance accept --installmongodb true --mongodir $schedulerDatabasePath --prefix $schedulerRepositoryPath &> $installFile.txt
  installFileLog="/tmp/bitrock_installer.log"
  cp $installFileLog $binDirectory/bitrock_installer_server.log
  rm -f $installFileLog
  cp $schedulerDatabasePath/certs/$schedulerCertificateFile $schedulerRepositoryPath/$schedulerCertificateFile
  chmod +r $schedulerRepositoryPath/$schedulerCertificateFile
  echo "$schedulerRepositoryPath *(rw,no_root_squash)" >> /etc/exports
  exportfs -a
  echo "Customize (End): Deadline Repository"
fi

echo "Customize (Start): Deadline Client"
installFile="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
if [ $subnetName == "Scheduler" ]; then
  clientArgs="--slavestartup false --launcherdaemon false"
else
  [ $subnetName == "Farm" ] && workerStartup=true || workerStartup=false
  clientArgs="--slavestartup $workerStartup --launcherdaemon true"
fi
./$installFile --mode unattended $clientArgs &> $installFile.txt
cp /tmp/bitrock_installer.log $binDirectory/bitrock_installer_client.log
deadlineCommandName="ChangeLicenseMode"
$schedulerPath/deadlinecommand -$deadlineCommandName $schedulerLicense &> $deadlineCommandName.txt
deadlineCommandName="ChangeRepositorySkipValidation"
$schedulerPath/deadlinecommand -$deadlineCommandName Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate "" &> $deadlineCommandName.txt
echo "Customize (End): Deadline Client"

if [[ $renderEngines == *Maya* ]]; then
  echo "Customize (Start): Maya"
  yum -y install libGL
  yum -y install libGLU
  yum -y install libjpeg
  yum -y install libtiff
  yum -y install libXp
  yum -y install libXmu
  yum -y install libXpm
  yum -y install libXi
  yum -y install libXinerama
  yum -y install libXrender
  yum -y install libXrandr
  yum -y install libXcomposite
  yum -y install libXcursor
  yum -y install libXtst
  yum -y install libxkbcommon
  yum -y install fontconfig
  fileVersion="2022_1"
  installFile="Autodesk_Maya_${fileVersion}_ML_Linux_64bit.tgz"
  downloadUrl="$storageContainerUrl/Maya/$fileVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  localDirectory="maya"
  mkdir $localDirectory
  tar --directory=$localDirectory -xzf $installFile
  cd $localDirectory/Packages
  rpm -i Maya2022*
  rpm -i MayaUSD*
  rpm -i Pymel*
  rpm -i Rokoko*
  rpm -i Bifrost*
  rpm -i Substance*
  cd $binDirectory
  echo "Customize (End): Maya"
fi

if [[ $renderEngines == *Nuke* ]]; then
  echo "Customize (Start): Nuke"
  fileVersion="13.1v2"
  installFile="Nuke$fileVersion-linux-x86_64.tgz"
  downloadUrl="$storageContainerUrl/Nuke/$fileVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  tar -xzf $installFile
  mkdir -p $rendererPathNuke
  ./Nuke*.run --accept-foundry-eula --prefix=$rendererPathNuke --exclude-subdir
  cd $binDirectory
  echo "Customize (End): Nuke"
fi

if [[ $renderEngines == *Unreal* ]]; then
  echo "Customize (Start): Unreal"
  fileVersion="5.0.0"
  installFile="UnrealEngine-$fileVersion-early-access-2.tar.gz"
  downloadUrl="$storageContainerUrl/Unreal/$fileVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  tar -xf $installFile
  cd UnrealEngine*
  mkdir -p $rendererPathUnreal
  mv * $rendererPathUnreal
  $rendererPathUnreal/Setup.sh
  cd $binDirectory
  echo "Customize (End): Unreal"
fi

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender"
  yum -y install libXi
  yum -y install libXxf86vm
  yum -y install libXfixes
  yum -y install libXrender
  yum -y install libGL
  fileVersion="3.1.0"
  installFile="blender-$fileVersion-linux-x64.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$fileVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  tar -xJf $installFile
  mkdir -p $rendererPathBlender
  cd blender*
  mv * $rendererPathBlender
  cd $binDirectory
  echo "Customize (End): Blender"
fi

if [ $subnetName == "Workstation" ]; then
  echo "Customize (Start): Workstation Desktop"
  yum -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

  echo "Customize (Start): Teradici PCoIP Agent"
  fileVersion="22.01.1"
  installFile="teradici-pcoip-agent_rpm.sh"
  downloadUrl="$storageContainerUrl/Teradici/$fileVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  chmod +x $installFile
  ./$installFile &> $installFile.txt
  yum -y install epel-release
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
  echo "Customize (End): Teradici PCoIP Agent"
fi
