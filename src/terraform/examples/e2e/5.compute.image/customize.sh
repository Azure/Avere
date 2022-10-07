#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

storageContainerUrl="https://azrender.blob.core.windows.net/bin"
storageContainerSas="?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D"

echo "Customize (Start): Platform Utilities"
yum -y install epel-release
yum -y install python-pip
yum -y install nfs-utils
yum -y install cmake
yum -y install gcc
yum -y install git
yum -y install jq
echo "Customize (End): Platform Utilities"

echo "Customize (Start): Image Build Parameters"
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
machineSize=$(echo $buildConfig | jq -r .machineSize)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
adminPassword=$(echo $buildConfig | jq -r .adminPassword)
echo "Machine Type: $machineType"
echo "Machine Size: $machineSize"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

#   NVv3 (https://learn.microsoft.com/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://learn.microsoft.com/azure/virtual-machines/nct4-v3-series)
#   NVv5 (https://learn.microsoft.com/azure/virtual-machines/nva10v5-series)
if [[ ($machineSize == Standard_NV* && $machineSize == *_v3) ||
      ($machineSize == Standard_NC* && $machineSize == *_T4_v3) ||
      ($machineSize == Standard_NV* && $machineSize == *_v5) ]]; then
  echo "Customize (Start): NVIDIA GPU GRID Driver"
  yum -y install "kernel-devel-$(uname --kernel-release)"
  installFile="nvidia-gpu-grid.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent &> $installFile.txt
  echo "Customize (End): NVIDIA GPU GRID Driver"
fi

if [ $machineType == "Scheduler" ]; then
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

if [ $machineType == "Scheduler" ]; then
  echo "Customize (Start): NFS Server"
  systemctl --now enable nfs-server
  echo "Customize (End): NFS Server"

  echo "Customize (Start): CycleCloud"
  cycleCloudRepoPath="/etc/yum.repos.d/cyclecloud.repo"
  echo "[cyclecloud]" > $cycleCloudRepoPath
  echo "name=CycleCloud" >> $cycleCloudRepoPath
  echo "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud" >> $cycleCloudRepoPath
  echo "gpgcheck=1" >> $cycleCloudRepoPath
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $cycleCloudRepoPath
  yum -y install cyclecloud8
  cd /opt/cycle_server
  sed -i 's/webServerEnableHttps=false/webServerEnableHttps=true/' ./config/cycle_server.properties
  unzip ./tools/cyclecloud-cli.zip
  ./cyclecloud-cli-installer/install.sh --installdir /usr/local/cyclecloud
  cycleCloudAdminName="cc_admin"
  cycleCloudInitFile="cycle_initialize.json"
  echo "[" > $cycleCloudInitFile
  echo "{" >> $cycleCloudInitFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleCloudInitFile
  echo "\"Name\": \"cycleserver.installation.initial_user\"," >> $cycleCloudInitFile
  echo "\"Value\": \"$cycleCloudAdminName\"" >> $cycleCloudInitFile
  echo "}," >> $cycleCloudInitFile
  echo "{" >> $cycleCloudInitFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleCloudInitFile
  echo "\"Name\": \"distribution_method\"," >> $cycleCloudInitFile
  echo "\"Category\": \"system\"," >> $cycleCloudInitFile
  echo "\"Status\": \"internal\"," >> $cycleCloudInitFile
  echo "\"Value\": \"manual\"" >> $cycleCloudInitFile
  echo "}," >> $cycleCloudInitFile
  echo "{" >> $cycleCloudInitFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleCloudInitFile
  echo "\"Name\": \"cycleserver.installation.complete\"," >> $cycleCloudInitFile
  echo "\"Value\": true" >> $cycleCloudInitFile
  echo "}," >> $cycleCloudInitFile
  echo "{" >> $cycleCloudInitFile
  echo "\"AdType\": \"AuthenticatedUser\"," >> $cycleCloudInitFile
  echo "\"Name\": \"$cycleCloudAdminName\"," >> $cycleCloudInitFile
  echo "\"RawPassword\": \"$adminPassword\"," >> $cycleCloudInitFile
  echo "\"Superuser\": true" >> $cycleCloudInitFile
  echo "}" >> $cycleCloudInitFile
  echo "]" >> $cycleCloudInitFile
  mv $cycleCloudInitFile /opt/cycle_server/config/data/
  echo "Customize (End): CycleCloud"
fi

schedulerVersion="10.1.23.6"
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
echo "PATH=$PATH:$schedulerPath$rendererPaths:$nodeDirectory:/usr/local/cyclecloud/bin" > /etc/profile.d/aaa.sh

echo "Customize (Start): Deadline Download"
installFile="Deadline-$schedulerVersion-linux-installers.tar"
downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
curl -o $installFile -L $downloadUrl
tar -xzf $installFile
echo "Customize (End): Deadline Download"

if [ $machineType == "Scheduler" ]; then
  echo "Customize (Start): Deadline Repository"
  installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
  ./$installFile --mode unattended --dbLicenseAcceptance accept --installmongodb true --dbhost localhost --mongodir $schedulerDatabasePath --prefix $schedulerRepositoryPath &> $installFile.txt
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
installArgs="--mode unattended"
if [ $machineType == "Scheduler" ]; then
  installArgs="$installArgs --slavestartup false --launcherdaemon false"
else
  [ $machineType == "Farm" ] && workerStartup=true || workerStartup=false
  installArgs="$installArgs --slavestartup $workerStartup --launcherdaemon true"
fi
./$installFile $installArgs &> $installFile.txt
cp /tmp/bitrock_installer.log $binDirectory/bitrock_installer_client.log
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
  versionInfo="3.3.1"
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

if [[ $renderEngines == *Unity* ]]; then
  echo "Customize (Start): Unity"
  unityRepoPath="/etc/yum.repos.d/unityhub.repo"
  echo "[unityhub]" > $unityRepoPath
  echo "name=Unity Hub" >> $unityRepoPath
  echo "baseurl=https://hub.unity3d.com/linux/repos/rpm/stable" >> $unityRepoPath
  echo "enabled=1" >> $unityRepoPath
  echo "gpgcheck=1" >> $unityRepoPath
  echo "gpgkey=https://hub.unity3d.com/linux/repos/rpm/stable/repodata/repomd.xml.key" >> $unityRepoPath
  echo "repo_gpgcheck=1" >> $unityRepoPath
  yum -y install unityhub
  echo "Customize (End): Unity"
fi

if [[ $renderEngines == *Unreal* ]]; then
  echo "Customize (Start): Unreal Engine"
  yum -y install libicu
  versionInfo="5.0.3"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$storageContainerUrl/Unreal/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  mkdir -p $rendererPathUnreal
  tar -xzf $installFile -C $rendererPathUnreal
  mv $rendererPathUnreal/Unreal*/* $rendererPathUnreal
  $rendererPathUnreal/Setup.sh
  # $rendererPathUnreal/GenerateProjectFiles.sh
  # make -C $rendererPathUnreal

  # echo "Customize (Start): Unreal Pixel Streaming"
  # cd $rendererPathUnreal/Samples/PixelStreaming/WebServers/SignallingWebServer/platform_scripts/bash
  # chmod +x *.sh
  # ./setup.sh
  # cd $rendererPathUnreal/Samples/PixelStreaming/WebServers/MatchMaker/platform_scripts/bash
  # chmod +x *.sh
  # ./setup.sh
  # cd $binDirectory
  # echo "Customize (End): Unreal Pixel Streaming"
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

if [ $machineType == "Farm" ]; then
  if [ -f /tmp/onTerminate.sh ]; then
    echo "Customize (Start): CycleCloud Event Handler"
    mkdir -p /opt/cycle/jetpack/scripts
    cp /tmp/onTerminate.sh /opt/cycle/jetpack/scripts/onPreempt.sh
    cp /tmp/onTerminate.sh /opt/cycle/jetpack/scripts/onTerminate.sh
    echo "Customize (End): CycleCloud Event Handler"
  fi
fi

if [ $machineType == "Workstation" ]; then
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
  yum -y install usb-vhci
  yum -y install pcoip-agent-graphics
  echo "Customize (End): Teradici PCoIP Agent"

  # echo "Customize (Start): Cinebench"
  # versionInfo="R23"
  # installFile="Cinebench$versionInfo.zip"
  # downloadUrl="$storageContainerUrl/Cinebench/$versionInfo/$installFile$storageContainerSas"
  # curl -o $installFile -L $downloadUrl
  # unzip $installFile
  # echo "Customize (End): Cinebench"

  # echo "Customize (Start): VRay Benchmark"
  # versionInfo="5.02.00"
  # installFile="vray-benchmark-$versionInfo"
  # downloadUrl="$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  # curl -o $installFile -L $downloadUrl
  # chmod +x $installFile
  # echo "Customize (End): VRay Benchmark"

  # echo "Customize (Start): Visual Studio Code"
  # yum -y install libX11
  # yum -y install libXcomposite
  # yum -y install libXdamage
  # yum -y install libXext
  # yum -y install libXrandr
  # yum -y install libsecret
  # yum -y install libxkbfile
  # yum -y install atk
  # yum -y install at-spi2-atk
  # yum -y install cairo
  # yum -y install gdk-pixbuf2
  # yum -y install gtk3
  # installFile="vscode.rpm"
  # downloadUrl="https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64"
  # curl -o $installFile -L $downloadUrl
  # rpm -i $installFile
fi
