#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

storageContainerUrl="https://azartist.blob.core.windows.net/bin"
storageContainerSas="?sv=2020-10-02&st=2022-01-01T00%3A00%3A00Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=4N8gUHTPNOG%2BlgEPvQljsRPCOsRD3ZWfiBKl%2BRxl9S8%3D"

echo "Customize (Start): Dev Platform"
yum -y group install "Development Tools"
versionInfo="1.1.1n"
installFile="openssl-$versionInfo.tar.gz"
downloadUrl="https://www.openssl.org/source/$installFile"
curl -o $installFile -L $downloadUrl
tar -xf $installFile
cd openssl*
./config
make
make install
export LD_LIBRARY_PATH=/usr/local/lib64:/usr/lib64
echo "/usr/local/lib64" > /etc/ld.so.conf.d/openssl-$versionInfo.conf
sslProfile="/etc/profile.d/openssl.sh"
echo 'OPENSSL_PATH="/usr/local/bin"' > $sslProfile
echo 'export OPENSSL_PATH' >> $sslProfile
echo 'PATH=$PATH:$OPENSSL_PATH' >> $sslProfile
echo 'export PATH' >> $sslProfile
source $sslProfile
cd $binDirectory
versionInfo="3.10.4"
installFile="Python-$versionInfo.tar.xz"
downloadUrl="https://www.python.org/ftp/python/$versionInfo/$installFile"
curl -o $installFile -L $downloadUrl
tar -xJf $installFile
cd Python*
./configure --enable-optimizations
make altinstall
cd $binDirectory
yum -y install epel-release
yum -y install python-pip
yum -y install nfs-utils
yum -y install jq
echo "Customize (End): Dev Platform"

echo "Customize (Start): Build Parameters"
buildJson=$(echo $buildJsonEncoded | base64 -d)
subnetName=$(echo $buildJson | jq -r .subnetName)
echo "Subnet Name: $subnetName"
machineSize=$(echo $buildJson | jq -r .machineSize)
echo "Machine Size: $machineSize"
renderEngines=$(echo $buildJson | jq -c .renderEngines)
echo "Render Engines: $renderEngines"
echo "Customize (End): Build Parameters"

#   NVv3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nct4-v3-series)
if [[ ($machineSize == Standard_NV* && $machineSize == *_v3) ||
      ($machineSize == Standard_NC* && $machineSize == *T4_v3) ]]; then
  echo "Customize (Start): GPU Driver (NVv3)"
  yum -y install "kernel-devel-$(uname --kernel-release)"
  installFile="nvidia-gpu-nv3.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent &> $installFile.txt
  echo "Customize (End): GPU Driver (NVv3)"
fi

# NVv4 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series)
if [[ $machineSize == Standard_NV* && $machineSize == *_v4 ]]; then
  echo "Customize (Start): GPU Driver (NVv4)"
  installFile="amd-gpu-nv4.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -o $installFile -L $downloadUrl
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
  yum -y install "kernel-devel-$(uname --kernel-release)"
  installFile="nvidia-gpu-nv5.run"
  downloadUrl="https://download.microsoft.com/download/4/3/9/439aea00-a02d-4875-8712-d1ab46cf6a73/NVIDIA-Linux-x86_64-510.47.03-grid-azure.run"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent &> $installFile.txt
  echo "Customize (End): GPU Driver (NVv5)"
fi

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
rendererPathPBRT="/usr/local/pbrt3"
rendererPathNuke="/usr/local/nuke13"
rendererPathUnreal="/usr/local/unreal5"
rendererPathBlender="/usr/local/blender3"
rendererPathHoudini="/usr/local/houdini19"
if [[ $renderEngines == *Maya* ]]; then
  rendererPaths="$rendererPaths:$rendererPathMaya"
fi
if [[ $renderEngines == *PBRT* ]]; then
  rendererPaths="$rendererPaths:$rendererPathPBRT"
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
if [[ $renderEngines == *Houdini* ]]; then
  rendererPaths="$rendererPaths:$rendererPathHoudini/bin"
fi
echo "PATH=$PATH:$schedulerPath$rendererPaths" >> /etc/profile.d/aaa.sh

echo "Customize (Start): Deadline Download"
installFile="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
curl -o $installFile -L $downloadUrl
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
  versionInfo="2022_3"
  installFile="Autodesk_Maya_${versionInfo}_ML_Linux_64bit.tgz"
  downloadUrl="$storageContainerUrl/Maya/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  mayaDirectory="Maya"
  mkdir $mayaDirectory
  tar --directory=$mayaDirectory -xzf $installFile
  cd $mayaDirectory/Packages
  rpm -i Maya2022*
  rpm -i MayaUSD*
  rpm -i Pymel*
  rpm -i Rokoko*
  rpm -i Bifrost*
  rpm -i Substance*
  cd $binDirectory
  echo "Customize (End): Maya"
fi

if [[ $renderEngines == *PBRT* ]]; then
  echo "Customize (Start): PBRT"
  pip install cmake
  versionInfo="v3"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git
  mkdir -p $rendererPathPBRT
  cd $rendererPathPBRT
  cmake $binDirectory/pbrt-$versionInfo/
  make
  cd $binDirectory
  echo "Customize (End): PBRT"
fi

if [[ $renderEngines == *Nuke* ]]; then
  echo "Customize (Start): Nuke"
  versionInfo="13.1v2"
  installFile="Nuke$versionInfo-linux-x86_64.tgz"
  downloadUrl="$storageContainerUrl/Nuke/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  mkdir -p $rendererPathNuke
  ./Nuke*.run --accept-foundry-eula --prefix=$rendererPathNuke --exclude-subdir
  cd $binDirectory
  echo "Customize (End): Nuke"
fi

if [[ $renderEngines == *Unreal* ]]; then
  echo "Customize (Start): Unreal"
  versionInfo="5.0.0"
  installFile="UnrealEngine-$versionInfo-early-access-2.tar.gz"
  downloadUrl="$storageContainerUrl/Unreal/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
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
  versionInfo="3.1.2"
  installFile="blender-$versionInfo-linux-x64.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xJf $installFile
  mkdir -p $rendererPathBlender
  cd blender*
  mv * $rendererPathBlender
  cd $binDirectory
  echo "Customize (End): Blender"
fi

if [[ $renderEngines == *Houdini* ]]; then
  echo "Customize (Start): Houdini"
  yum -y install libGL
  yum -y install libXi
  yum -y install libXtst
  yum -y install libXrender
  yum -y install libXrandr
  yum -y install libXcursor
  yum -y install libXcomposite
  yum -y install libXScrnSaver
  yum -y install libxkbcommon
  yum -y install fontconfig
  versionInfo="19.0.561"
  versionEULA="2021-10-13"
  installFile="houdini-$versionInfo-linux_x86_64_gcc9.3.tar.gz"
  downloadUrl="$storageContainerUrl/Houdini/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xf $installFile
  [[ $renderEngines == *Maya* ]] && mayaPlugIn=--install-engine-maya || mayaPlugIn=--no-install-engine-maya
  [[ $renderEngines == *Unreal* ]] && unrealPlugIn=--install-engine-unreal || unrealPlugIn=--no-install-engine-unreal
  cd houdini*
  ./houdini.install --auto-install --make-dir --accept-EULA $versionEULA $mayaPlugIn $unrealPlugIn $rendererPathHoudini
  cd $binDirectory
  echo "Customize (End): Houdini"
fi

if [ $subnetName == "Workstation" ]; then
  echo "Customize (Start): Workstation Desktop"
  yum -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

  echo "Customize (Start): Teradici PCoIP Agent"
  versionInfo="22.01.1"
  installFile="teradici-pcoip-agent_rpm.sh"
  downloadUrl="$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile &> $installFile.txt
  yum -y install epel-release
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
  echo "Customize (End): Teradici PCoIP Agent"
fi
