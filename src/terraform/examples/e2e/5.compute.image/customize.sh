#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

storageContainerUrl="https://azrender.blob.core.windows.net/bin"
storageContainerSas="?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D"

echo "Customize (Start): Image Build Parameters"
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
machineSize=$(echo $buildConfig | jq -r .machineSize)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
adminUsername=$(echo $buildConfig | jq -r .adminUsername)
adminPassword=$(echo $buildConfig | jq -r .adminPassword)
echo "Machine Type: $machineType"
echo "Machine Size: $machineSize"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

echo "Customize (Start): Platform Utilities"
dnf -y install epel-release
dnf -y install gcc gcc-c++
dnf -y install nfs-utils
dnf -y install cmake
dnf -y install git
echo "Customize (End): Platform Utilities"

#   NVv5 (https://learn.microsoft.com/azure/virtual-machines/nva10v5-series)
# NCT4v3 (https://learn.microsoft.com/azure/virtual-machines/nct4-v3-series)
#   NVv3 (https://learn.microsoft.com/azure/virtual-machines/nvv3-series)
if [[ ($machineSize == Standard_NV* && $machineSize == *_v5) ||
      ($machineSize == Standard_NC* && $machineSize == *_T4_v3) ||
      ($machineSize == Standard_NV* && $machineSize == *_v3) ]]; then
  echo "Customize (Start): NVIDIA GPU GRID Driver"
  dnf -y install make
  dnf -y install elfutils-libelf-devel
  dnf -y install "kernel-devel-$(uname --kernel-release)"
  installFile="nvidia-gpu-grid.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent
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
  dnf -y install azure-cli
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
  dnf -y install java-1.8.0-openjdk
  JAVA_HOME=/bin/java
  dnf -y install cyclecloud8
  cd /opt/cycle_server
  sed -i 's/webServerEnableHttps=false/webServerEnableHttps=true/' ./config/cycle_server.properties
  unzip -q ./tools/cyclecloud-cli.zip
  ./cyclecloud-cli-installer/install.sh --installdir /usr/local/cyclecloud
  cd $binDirectory
  cycleCloudInitFile="cycle_initialize.json"
  echo "[" > $cycleCloudInitFile
  echo "{" >> $cycleCloudInitFile
  echo "\"AdType\": \"Application.Setting\"," >> $cycleCloudInitFile
  echo "\"Name\": \"cycleserver.installation.initial_user\"," >> $cycleCloudInitFile
  echo "\"Value\": \"$adminUsername\"" >> $cycleCloudInitFile
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
  echo "\"Name\": \"$adminUsername\"," >> $cycleCloudInitFile
  echo "\"RawPassword\": \"$adminPassword\"," >> $cycleCloudInitFile
  echo "\"Superuser\": true" >> $cycleCloudInitFile
  echo "}" >> $cycleCloudInitFile
  echo "]" >> $cycleCloudInitFile
  mv $cycleCloudInitFile /opt/cycle_server/config/data/
  echo "Customize (End): CycleCloud"
fi

schedulerVersion="10.1.23.6"
schedulerPath="/opt/Thinkbox/Deadline10/bin"
schedulerDatabaseHost=$(hostname)
schedulerDatabasePort=27017
schedulerRepositoryPath="/DeadlineRepository"
schedulerCertificateName="Deadline10"
schedulerCertificateFile="$schedulerCertificateName.pfx"
schedulerRepositoryLocalMount="/mnt/scheduler"
schedulerRepositoryCertificate="$schedulerRepositoryLocalMount/$schedulerCertificateFile"

rendererPathBlender="/usr/local/blender3"
rendererPathPBRT3="/usr/local/pbrt/v3"
rendererPathPBRT4="/usr/local/pbrt/v4"
rendererPathUnreal="/usr/local/unreal5"
rendererPathUnrealStream="$rendererPathUnreal/stream"
rendererPathMaya="/usr/autodesk/maya2023/bin"
rendererPathHoudini="/usr/local/houdini19"

rendererPaths=""
if [[ $renderEngines == *Blender* ]]; then
  rendererPaths="$rendererPaths:$rendererPathBlender"
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
  dnf -y install python3.9
  pip3.9 install pyOpenSSL
  installFile="SSLGeneration-master.zip"
  downloadUrl="$storageContainerUrl/Deadline/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  cd "SSLGeneration-master"
  python3.9 ssl_gen.py --ca --cert-org Azure --cert-ou Render
  python3.9 ssl_gen.py --server --cert-name $schedulerCertificateName
  python3.9 ssl_gen.py --client --cert-name $schedulerCertificateName
  python3.9 ssl_gen.py --pfx --cert-name $schedulerCertificateName
  mkdir -p $schedulerRepositoryPath
  cp ./keys/$schedulerCertificateFile $schedulerRepositoryPath/$schedulerCertificateFile
  chmod +r $schedulerRepositoryPath/$schedulerCertificateFile
  cd $binDirectory
  mongoDbRepoPath="/etc/yum.repos.d/mongodb.repo"
  echo "[mongodb-org-4.2]" > $mongoDbRepoPath
  echo "name=MongoDB" >> $mongoDbRepoPath
  echo "baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/4.2/x86_64/" >> $mongoDbRepoPath
  echo "gpgcheck=1" >> $mongoDbRepoPath
  echo "enabled=1" >> $mongoDbRepoPath
  echo "gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc" >> $mongoDbRepoPath
  dnf -y install mongodb-org
  systemctl enable mongod
  systemctl start mongod
  installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
  ./$installFile --mode unattended --dbLicenseAcceptance accept --dbcacert $schedulerRepositoryPath/$schedulerCertificateFile --dbhost $schedulerDatabaseHost --dbport $schedulerDatabasePort --prefix $schedulerRepositoryPath
  mv /tmp/bitrock_installer.log $binDirectory/bitrock_installer_server.log
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
./$installFile $installArgs
mv /tmp/bitrock_installer.log $binDirectory/bitrock_installer_client.log
$schedulerPath/deadlinecommand -ChangeRepositorySkipValidation Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate ""
echo "Customize (End): Deadline Client"

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender"
  dnf -y install libXi
  dnf -y install libXxf86vm
  dnf -y install libXfixes
  dnf -y install libXrender
  dnf -y install libGL
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
  echo "Customize (Start): PBRT v3"
  versionInfo="v3"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git
  mkdir -p $rendererPathPBRT3
  cmake -B $rendererPathPBRT3 -S $binDirectory/pbrt-$versionInfo/
  make -C $rendererPathPBRT3
  ln -s $rendererPathPBRT3/pbrt /usr/bin/pbrt3
  echo "Customize (End): PBRT v3"
  echo "Customize (Start): PBRT v4"
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  dnf -y install libXi-devel
  versionInfo="v4"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git
  mkdir -p $rendererPathPBRT4
  cmake -B $rendererPathPBRT4 -S $binDirectory/pbrt-$versionInfo/
  make -C $rendererPathPBRT4
  ln -s $rendererPathPBRT4/pbrt /usr/bin/pbrt4
  echo "Customize (End): PBRT v4"
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
  dnf -y install unityhub
  echo "Customize (End): Unity"
fi

if [[ $renderEngines == *Unreal* ]]; then
  echo "Customize (Start): Unreal Engine"
  dnf -y install libicu
  versionInfo="5.1"
  installFile="UnrealEngine-$versionInfo.zip"
  downloadUrl="$storageContainerUrl/Unreal/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  cd UnrealEngine-$versionInfo
  mkdir -p $rendererPathUnreal
  mv * $rendererPathUnreal
  $rendererPathUnreal/Setup.sh
  cd $binDirectory
  if [ $machineType == "Workstation" ]; then
    echo "Customize (Start): Unreal Project Files"
    $rendererPathUnreal/GenerateProjectFiles.sh
    make -C $rendererPathUnreal
    echo "Customize (End): Unreal Project Files"
  fi
  echo "Customize (End): Unreal Engine"
fi

if [[ $renderEngines == *Unreal,PixelStream* ]]; then
  echo "Customize (Start): Unreal Pixel Streaming"
  versionInfo="5.1"
  installFile="PixelStreamingInfrastructure-UE$versionInfo.zip"
  downloadUrl="$storageContainerUrl/Unreal/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  cd PixelStreamingInfrastructure-UE$versionInfo
  mkdir -p $rendererPathUnrealStream
  mv * $rendererPathUnrealStream
  cd $rendererPathUnrealStream/SignallingWebServer/platform_scripts/bash
  chmod +x *.sh
  ./setup.sh
  cd $rendererPathUnrealStream/MatchMaker/platform_scripts/bash
  chmod +x *.sh
  ./setup.sh
  cd $binDirectory
  echo "Customize (End): Unreal Pixel Streaming"
fi

if [[ $renderEngines == *Maya* ]]; then
  echo "Customize (Start): Maya"
  dnf -y install libGL
  dnf -y install libGLU
  dnf -y install libjpeg
  dnf -y install libtiff
  dnf -y install libXmu
  dnf -y install libXpm
  dnf -y install libXi
  dnf -y install libXinerama
  dnf -y install libXrender
  dnf -y install libXrandr
  dnf -y install libXcomposite
  dnf -y install libXcursor
  dnf -y install libXtst
  dnf -y install libxkbcommon
  dnf -y install fontconfig
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
  dnf -y install libGL
  dnf -y install libXi
  dnf -y install libXtst
  dnf -y install libXrender
  dnf -y install libXrandr
  dnf -y install libXcursor
  dnf -y install libXcomposite
  dnf -y install libXScrnSaver
  dnf -y install libxkbcommon
  dnf -y install fontconfig
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
  dnf config-manager --set-enabled powertools
  dnf -y groups install "KDE Plasma Workspaces"
  echo "Customize (End): Workstation Desktop"

  echo "Customize (Start): Teradici PCoIP Agent"
  versionInfo="22.09.0"
  installFile="pcoip-agent-offline-centos7.9_$versionInfo-1.el7.x86_64.tar.gz"
  downloadUrl="$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  ./install-pcoip-agent.sh pcoip-agent-graphics usb-vhci
  echo "Customize (End): Teradici PCoIP Agent"

  echo "Customize (Start): V-Ray Benchmark"
  versionInfo="5.02.00"
  installFile="vray-benchmark-$versionInfo"
  downloadUrl="$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  echo "Customize (End): V-Ray Benchmark"
fi
