#!/bin/bash -ex

homeDirectory="/usr/local"
cd $homeDirectory

#   NVv3 - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
# NCT4v3 - https://docs.microsoft.com/en-us/azure/virtual-machines/nct4-v3-series
if [[ ($machineSize == Standard_NV* && $machineSize == *_v3) ||
      ($machineSize == Standard_NC* && $machineSize == *T4_v3) ]]; then
  echo "Customize (Start): GPU Driver (NVv3)"
  yum -y install gcc
  yum -y install "kernel-devel-uname-r == $(uname -r)"
  installFile="nvidia-gpu.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -L -o $installFile $downloadUrl
  chmod +x $installFile
  ./$installFile --silent
  echo "Customize (End): GPU Driver (NVv3)"
fi

# NVv4 - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if [[ $machineSize == Standard_NV* && $machineSize == *_v4 ]]; then
  echo "Customize (Start): GPU Driver (NVv4)"
  installFile="amd-gpu.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -L -o $installFile $downloadUrl
  tar -xJf $installFile
  cd amdgpu*
  installFile="amdgpu-pro-install"
  ./$installFile -y --opencl=legacy,pal
  cd $homeDirectory
  echo "Customize (End): GPU Driver (NVv4)"
fi

if [ $subnetName == "Scheduler" ]; then
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

rendererPaths=""
schedulerPath="/opt/Thinkbox/Deadline10/bin"
rendererPathBlender="/usr/local/Blender"
rendererPathMaya="/usr/autodesk/Maya2022"
rendererPathUnreal="/usr/local/Unreal"
if [[ $renderEngines == *Blender* ]]; then
  rendererPaths="$rendererPaths:$rendererPathBlender"
fi
if [[ $renderEngines == *Maya* ]]; then
  rendererPaths="$rendererPaths:$rendererPathMaya"
fi
if [[ $renderEngines == *Unreal* ]]; then
  rendererPaths="$rendererPaths:$rendererPathUnreal"
fi
echo "PATH=$PATH:$schedulerPath$rendererPaths" >> /etc/profile.d/aaa.sh

echo "Customize (Start): Deadline Download"
installFile="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
curl -L -o $installFile $downloadUrl
tar -xf $installFile
echo "Customize (End): Deadline Download"

echo "Customize (Start): Deadline Client"
installFile="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
if [ $subnetName == "Scheduler" ]; then
  clientArgs="--slavestartup false --launcherdaemon false"
else
  useradd $userName
  [ $subnetName == "Farm" ] && workerStartup=true || workerStartup=false
  clientArgs="--slavestartup $workerStartup --launcherdaemon true --daemonuser $userName"
fi
./$installFile --mode unattended --licensemode $schedulerLicense $clientArgs
installFile="$schedulerPath/deadlinecommand"
$installFile -ChangeRepositorySkipValidation Direct /mnt/scheduler
$installFile -ChangeLicenseMode $schedulerLicense
echo "Customize (End): Deadline Client"

if [ $subnetName == "Scheduler" ]; then
  echo "Customize (Start): Deadline Repository"
  installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
  ./$installFile --mode unattended --dbLicenseAcceptance accept --installmongodb true --prefix $schedulerRepositoryPath --mongodir $schedulerDatabasePath --dbuser $userName --dbpassword $userPassword --requireSSL false
  systemctl start nfs-server
  systemctl enable nfs-server
  echo "$schedulerRepositoryPath *(rw,no_root_squash)" >> /etc/exports
  exportfs -a
  echo "Customize (End): Deadline Repository"
fi

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender"
  yum -y install libXi
  yum -y install libXxf86vm
  yum -y install libXfixes
  yum -y install libXrender
  yum -y install libGL
  rendererVersion="3.0.1"
  installFile="blender-$rendererVersion-linux-x64.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$rendererVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  tar -xJf $installFile
  cd blender*
  mkdir -p $rendererPathBlender
  mv * $rendererPathBlender
  cd $homeDirectory
  echo "Customize (End): Blender"
fi

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
  yum -y install libxkbcommon-x11
  yum -y install xcb-util-wm
  yum -y install xcb-util-image
  yum -y install xcb-util-keysyms
  yum -y install xcb-util-renderutil
  yum -y install libwayland-cursor
  yum -y install fontconfig
  yum -y install harfbuzz
  rendererVersion="2022"
  installFile="Autodesk_Maya_2022_1_ML_Linux_64bit.tgz"
  downloadUrl="$storageContainerUrl/Maya/$rendererVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  localDirectory="Maya"
  mkdir $localDirectory
  tar --directory=$localDirectory -xzf $installFile
  cd $localDirectory/Packages
  rpm -i Maya2022*
  rpm -i MayaUSD*
  rpm -i Rokoko*
  rpm -i Bifrost*
  rpm -i Substance*
  cd $homeDirectory
  echo "Customize (End): Maya"
fi

if [[ $renderEngines == *Unreal* ]]; then
  echo "Customize (Start): Unreal"
  rendererVersion="5.0.0"
  installFile="UnrealEngine-$rendererVersion-early-access-2.tar.gz"
  downloadUrl="$storageContainerUrl/Unreal/$rendererVersion/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  tar -xf $installFile
  cd UnrealEngine*
  mkdir -p $rendererPathUnreal
  mv * $rendererPathUnreal
  $rendererPathUnreal/Setup.sh
  cd $homeDirectory
  echo "Customize (End): Unreal"
fi

if [ $subnetName == "Workstation" ]; then
  echo "Customize (Start): Workstation Desktop"
  yum -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

  echo "Customize (Start): Teradici PCoIP Agent"
  installFile="teradici-pcoip-agent_rpm.sh"
  downloadUrl="$storageContainerUrl/Teradici/$installFile$storageContainerSas"
  curl -L -o $installFile $downloadUrl
  chmod +x $installFile
  ./$installFile
  yum -y install epel-release
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
  echo "Customize (End): Teradici PCoIP Agent"
fi
