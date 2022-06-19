#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

storageContainerUrl="https://azartist.blob.core.windows.net/bin"
storageContainerSas="?sv=2020-10-02&st=2022-01-01T00%3A00%3A00Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=4N8gUHTPNOG%2BlgEPvQljsRPCOsRD3ZWfiBKl%2BRxl9S8%3D"

echo "Customize (Start): Platform Utilities"
yum -y install epel-release
yum -y install python-pip
yum -y install nfs-utils
yum -y install jq
echo "Customize (End): Platform Utilities"

echo "Customize (Start): Image Build Parameters"
buildJson=$(echo $buildJsonEncoded | base64 -d)
subnetName=$(echo $buildJson | jq -r .subnetName)
machineSize=$(echo $buildJson | jq -r .machineSize)
outputVersion=$(echo $buildJson | jq -r .outputVersion)
renderEngines=$(echo $buildJson | jq -c .renderEngines)
adminPassword=$(echo $buildJson | jq -r .adminPassword)
echo "Subnet Name: $subnetName"
echo "Machine Size: $machineSize"
echo "Output Version: $outputVersion"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

echo "Customize (Start): Dev Tools"
yum -y group install "Development Tools"
echo "Customize (End): Dev Tools"

#   NVv3 (https://docs.microsoft.com/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://docs.microsoft.com/azure/virtual-machines/nct4-v3-series)
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

# NVv4 (https://docs.microsoft.com/azure/virtual-machines/nvv4-series)
if [[ $machineSize == Standard_NV* && $machineSize == *_v4 ]]; then
  echo "Customize (Start): GPU Driver (NVv4)"
  installFile="amd-gpu-nv4.tar.xz"
  downloadUrl="https://download.microsoft.com/download/3/6/6/366e3bb8-cc4f-48ba-aae3-52bd096f816d/amdgpu-pro-21.10-1262503-rhel-7.9.tar.xz"
  curl -o $installFile -L $downloadUrl
  tar -xJf $installFile
  installFile="amdgpu-pro-install"
  ./amdgpu*/$installFile -y --opencl=legacy,pal &> $installFile.txt
  echo "Customize (End): GPU Driver (NVv4)"
fi

# NVv5 (https://docs.microsoft.com/azure/virtual-machines/nva10v5-series)
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

if [ $outputVersion == "0.0.0" ]; then
  echo "Customize (Start): NFS Server"
  systemctl --now enable nfs-server
  echo "Customize (End): NFS Server"

  echo "Customize (Start): CycleCloud"
  cycleCloudPath="/etc/yum.repos.d/cyclecloud.repo"
  echo "[cyclecloud]" > $cycleCloudPath
  echo "name=cyclecloud" >> $cycleCloudPath
  echo "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud" >> $cycleCloudPath
  echo "gpgcheck=1" >> $cycleCloudPath
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $cycleCloudPath
  yum -y install cyclecloud8
  cd /opt/cycle_server
  sed -i 's/webServerEnableHttps=false/webServerEnableHttps=true/' ./config/cycle_server.properties
  unzip ./tools/cyclecloud-cli.zip
  ./cyclecloud-cli-installer/install.sh --installdir /usr/local/cyclecloud
  cycleAdminAccountName="cc_admin"
  cycleInitializeFile="cycle_initialize.json"
  echo "[" > $cycleInitializeFile
  echo "{" >> $cycleInitializeFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleInitializeFile
  echo "\"Name\": \"cycleserver.installation.initial_user\"," >> $cycleInitializeFile
  echo "\"Value\": \"$cycleAdminAccountName\"" >> $cycleInitializeFile
  echo "}," >> $cycleInitializeFile
  echo "{" >> $cycleInitializeFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleInitializeFile
  echo "\"Name\": \"distribution_method\"," >> $cycleInitializeFile
  echo "\"Category\": \"system\"," >> $cycleInitializeFile
  echo "\"Status\": \"internal\"," >> $cycleInitializeFile
  echo "\"Value\": \"manual\"" >> $cycleInitializeFile
  echo "}," >> $cycleInitializeFile
  echo "{" >> $cycleInitializeFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleInitializeFile
  echo "\"Name\": \"cycleserver.installation.complete\"," >> $cycleInitializeFile
  echo "\"Value\": true" >> $cycleInitializeFile
  echo "}," >> $cycleInitializeFile
  echo "{" >> $cycleInitializeFile
  echo "\"AdType\": \"AuthenticatedUser\"," >> $cycleInitializeFile
  echo "\"Name\": \"$cycleAdminAccountName\"," >> $cycleInitializeFile
  echo "\"RawPassword\": \"$adminPassword\"," >> $cycleInitializeFile
  echo "\"Superuser\": true" >> $cycleInitializeFile
  echo "}" >> $cycleInitializeFile
  echo "]" >> $cycleInitializeFile
  mv $cycleInitializeFile /opt/cycle_server/config/data/
  installFile="cluster_template.txt"
  downloadUrl="$storageContainerUrl/CycleCloud/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  echo "Customize (End): CycleCloud"
fi

schedulerVersion="10.1.21.4"
schedulerLicense="LicenseFree"
schedulerPath="/opt/Thinkbox/Deadline10/bin"
schedulerDatabasePath="/DeadlineDatabase"
schedulerRepositoryPath="/DeadlineRepository"
schedulerCertificateFile="Deadline10Client.pfx"
schedulerRepositoryLocalMount="/mnt/scheduler"
schedulerRepositoryCertificate="$schedulerRepositoryLocalMount/$schedulerCertificateFile"

rendererPaths=""
rendererPathBlender="/usr/local/blender3"
rendererPathPBRT="/usr/local/pbrt3"
rendererPathUnreal="/usr/local/unreal5"
rendererPathMaya="/usr/autodesk/maya2023/bin"
rendererPathHoudini="/usr/local/houdini19"
if [[ $renderEngines == *Blender* ]]; then
  rendererPaths="$rendererPaths:$rendererPathBlender"
fi
if [[ $renderEngines == *PBRT* ]]; then
  rendererPaths="$rendererPaths:$rendererPathPBRT"
fi
if [[ $renderEngines == *Unreal* ]]; then
  rendererPaths="$rendererPaths:$rendererPathUnreal"
fi
if [[ $renderEngines == *Maya* ]]; then
  rendererPaths="$rendererPaths:$rendererPathMaya"
fi
if [[ $renderEngines == *Houdini* ]]; then
  rendererPaths="$rendererPaths:$rendererPathHoudini/bin"
fi
echo "PATH=$PATH:$schedulerPath$rendererPaths:/usr/local/cyclecloud/bin" > /etc/profile.d/aaa.sh

echo "Customize (Start): Deadline Download"
installFile="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
curl -o $installFile -L $downloadUrl
tar -xzf $installFile
echo "Customize (End): Deadline Download"

if [ $outputVersion == "0.0.0" ]; then
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
installArgs="--mode unattended --licensemode $schedulerLicense"
if [ $outputVersion == "0.0.0" ]; then
  installArgs="$installArgs --slavestartup false --launcherdaemon false"
else
  [ $subnetName == "Farm" ] && workerStartup=true || workerStartup=false
  installArgs="$installArgs --slavestartup $workerStartup --launcherdaemon true"
fi
./$installFile $installArgs &> $installFile.txt
cp /tmp/bitrock_installer.log $binDirectory/bitrock_installer_client.log
deadlineCommandName="ChangeLicenseMode"
$schedulerPath/deadlinecommand -$deadlineCommandName $schedulerLicense &> $deadlineCommandName.txt
deadlineCommandName="ChangeRepositorySkipValidation"
$schedulerPath/deadlinecommand -$deadlineCommandName Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate "" &> $deadlineCommandName.txt
echo "Customize (End): Deadline Client"

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender"
  yum -y install libXi
  yum -y install libXxf86vm
  yum -y install libXfixes
  yum -y install libXrender
  yum -y install libGL
  versionInfo="3.2.0"
  installFile="blender-$versionInfo-linux-x64.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xJf $installFile
  mkdir -p $rendererPathBlender
  mv blender*/* $rendererPathBlender
  echo "Customize (End): Blender"
fi

if [[ $renderEngines == *PBRT* ]]; then
  echo "Customize (Start): PBRT"
  pip install cmake
  versionInfo="v3"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git
  mkdir -p $rendererPathPBRT
  cmake -B $rendererPathPBRT -S $binDirectory/pbrt-$versionInfo/
  make -C $rendererPathPBRT
  echo "Customize (End): PBRT"
fi

if [[ $renderEngines == *Unreal* ]]; then
  echo "Customize (Start): Unreal Engine"
  yum -y install libicu
  versionInfo="5.0.2"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$storageContainerUrl/Unreal/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  mkdir -p $rendererPathUnreal
  tar -xzf $installFile -C $rendererPathUnreal
  mv $rendererPathUnreal/Unreal*/* $rendererPathUnreal
  $rendererPathUnreal/Setup.sh
  $rendererPathUnreal/GenerateProjectFiles.sh
  make -C $rendererPathUnreal
  echo "Customize (End): Unreal Engine"
fi

if [[ $renderEngines == *Maya* ]]; then
  echo "Customize (Start): Maya"
  yum -y install libGL
  yum -y install libGLU
  yum -y install libjpeg
  yum -y install libtiff
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
  versionInfo="2023"
  installFile="Autodesk_Maya_${versionInfo}_ML_Linux_64bit.tgz"
  downloadUrl="$storageContainerUrl/Maya/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  mayaDirectory="Maya"
  mkdir $mayaDirectory
  tar -C $mayaDirectory -xzf $installFile
  rpm -i $mayaDirectory/Packages/Maya202*.rpm
  rpm -i $mayaDirectory/Packages/MayaUSD*.rpm
  rpm -i $mayaDirectory/Packages/Pymel*.rpm
  rpm -i $mayaDirectory/Packages/Bifrost*.rpm
  rpm -i $mayaDirectory/Packages/*Substance*.rpm
  echo "Customize (End): Maya"
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
  tar -xzf $installFile
  [[ $renderEngines == *Maya* ]] && mayaPlugIn=--install-engine-maya || mayaPlugIn=--no-install-engine-maya
  [[ $renderEngines == *Unreal* ]] && unrealPlugIn=--install-engine-unreal || unrealPlugIn=--no-install-engine-unreal
  ./houdini*/houdini.install --auto-install --make-dir --accept-EULA $versionEULA $mayaPlugIn $unrealPlugIn $rendererPathHoudini
  echo "Customize (End): Houdini"
fi

if [ $subnetName == "Farm" ]; then
  if [ -f /tmp/onTerminate.sh ]; then
    echo "Customize (Start): Scheduled Event Handler"
    mkdir -p /opt/cycle/jetpack/scripts
    cp /tmp/onTerminate.sh /opt/cycle/jetpack/scripts/onPreempt.sh
    cp /tmp/onTerminate.sh /opt/cycle/jetpack/scripts/onTerminate.sh
    echo "Customize (End): Scheduled Event Handler"
  fi
fi

if [ $subnetName == "Workstation" ]; then
  echo "Customize (Start): Workstation Desktop"
  yum -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

  echo "Customize (Start): Teradici PCoIP Agent"
  versionInfo="22.04.0"
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

echo "Customize (Start): VRay Benchmark"
versionInfo="5.02.00"
installFile="vray-benchmark-$versionInfo"
downloadUrl="$storageContainerUrl/VRay/Benchmark/$installFile$storageContainerSas"
curl -o $installFile -L $downloadUrl
chmod +x $installFile
echo "Customize (End): VRay Benchmark"

echo "Customize (Start): NVIDIA OptiX SDK"
versionInfo="7.5.0"
installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64.sh"
downloadUrl="$storageContainerUrl/NVIDIA/OptiX/$installFile$storageContainerSas"
curl -o $installFile -L $downloadUrl
chmod +x $installFile
localDirectory="NVIDIA-OptiX"
mkdir $localDirectory
./$installFile --prefix=$localDirectory --skip-license
echo "Customize (End): NVIDIA OptiX SDK"
