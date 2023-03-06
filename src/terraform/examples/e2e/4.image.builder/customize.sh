#!/bin/bash -ex

binPaths=""
binDirectory="/usr/local/bin"
cd $binDirectory

storageContainerUrl="https://azrender.blob.core.windows.net/bin"
storageContainerSas="?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D"

echo "Customize (Start): Image Build Platform"
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
yum -y install epel-release
yum -y install gcc gcc-c++
yum -y install nfs-utils
yum -y install python3
# yum -y install unzip
# yum -y install cmake
yum -y install git
yum -y install jq

versionInfo="3.25.1"
installFile="cmake-$versionInfo-linux-x86_64.tar.gz"
downloadUrl="$storageContainerUrl/CMake/$versionInfo/$installFile$storageContainerSas"
curl -o $installFile -L $downloadUrl
tar -xzf $installFile
installDirectory="cmake"
mv cmake-$versionInfo-linux-x86_64 $installDirectory
binPathCMake="$(pwd)/$installDirectory/bin"
binPaths="$binPaths:$binPathCMake"
echo "Customize (End): Image Build Platform"

echo "Customize (Start): Image Build Parameters"
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
gpuPlatform=$(echo $buildConfig | jq -c .gpuPlatform)
renderManager=$(echo $buildConfig | jq -r .renderManager)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
echo "Machine Type: $machineType"
echo "GPU Platform: $gpuPlatform"
echo "Render Manager: $renderManager"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

if [[ $gpuPlatform == *GRID* ]]; then
  echo "Customize (Start): NVIDIA GPU (GRID)"
  yum -y install kernel-devel-$(uname -r)
  yum -y install dkms
  installFile="nvidia-gpu-grid.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent --dkms 1> "nvidia-gpu-grid.output.txt" 2> "nvidia-gpu-grid.error.txt"
  echo "Customize (End): NVIDIA GPU (GRID)"
fi

if [[ $gpuPlatform == *CUDA* ]] || [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA GPU (CUDA)"
  yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo
  yum -y install cuda 1> "nvidia-cuda.output.txt" 2> "nvidia-cuda.error.txt"
  echo "Customize (End): NVIDIA GPU (CUDA)"
fi

if [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA OptiX"
  versionInfo="7.6.0"
  installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64-31894579.sh"
  downloadUrl="$storageContainerUrl/NVIDIA/OptiX/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  installDirectory="nvidia-optix"
  mkdir $installDirectory
  ./$installFile --skip-license --prefix="$binDirectory/$installDirectory" 1> "nvidia-optix.output.txt" 2> "nvidia-optix.error.txt"
  yum -y install mesa-libGL-devel
  yum -y install libXrandr-devel
  yum -y install libXinerama-devel
  yum -y install libXcursor-devel
  buildDirectory="$binDirectory/$installDirectory/build"
  mkdir $buildDirectory
  $binPathCMake/cmake -B $buildDirectory -S "$binDirectory/$installDirectory/sdk" 1> "nvidia-optix-cmake.output.txt" 2> "nvidia-optix-cmake.error.txt"
  make -C $buildDirectory 1> "nvidia-optix-make.output.txt" 2> "nvidia-optix-make.error.txt"
  binPaths="$binPaths:$buildDirectory/bin"
  echo "Customize (End): NVIDIA OptiX"
fi

if [ $machineType == "Scheduler" ]; then
  echo "Customize (Start): Azure CLI"
  repoPath="/etc/yum.repos.d/azure-cli.repo"
  echo "[azure-cli]" > $repoPath
  echo "name=Azure CLI" >> $repoPath
  echo "baseurl=https://packages.microsoft.com/yumrepos/azure-cli" >> $repoPath
  echo "enabled=1" >> $repoPath
  echo "gpgcheck=1" >> $repoPath
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $repoPath
  yum -y install azure-cli 1> "az-cli.output.txt" 2> "az-cli.error.txt"
  echo "Customize (End): Azure CLI"

  if [[ $renderManager == *Deadline* ]]; then
    echo "Customize (Start): NFS Server"
    systemctl --now enable nfs-server
    echo "Customize (End): NFS Server"
  fi

  echo "Customize (Start): CycleCloud"
  cycleCloudPath="/usr/local/cyclecloud"
  repoPath="/etc/yum.repos.d/cyclecloud.repo"
  echo "[cyclecloud]" > $repoPath
  echo "name=CycleCloud" >> $repoPath
  echo "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud" >> $repoPath
  echo "gpgcheck=1" >> $repoPath
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $repoPath
  yum -y install java-1.8.0-openjdk
  JAVA_HOME=/bin/java
  yum -y install cyclecloud8
  cd /opt/cycle_server
  unzip -q ./tools/cyclecloud-cli.zip
  ./cyclecloud-cli-installer/install.sh --installdir $cycleCloudPath
  cd $binDirectory
  binPaths="$binPaths:$cycleCloudPath/bin"
  echo "Customize (End): CycleCloud"
fi

if [[ $renderManager == *Deadline* ]]; then
  schedulerVersion="10.2.0.10"
  schedulerInstallRoot="/deadline"
  schedulerDatabaseHost=$(hostname)
  schedulerDatabasePath="/deadlineDatabase"
  schedulerCertificateFile="Deadline10Client.pfx"
  schedulerCertificate="$schedulerInstallRoot/$schedulerCertificateFile"
  schedulerBinPath="$schedulerInstallRoot/bin"
  binPaths="$binPaths:$schedulerBinPath"

  echo "Customize (Start): Deadline Download"
  installFile="Deadline-$schedulerVersion-linux-installers.tar"
  downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  echo "Customize (End): Deadline Download"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Deadline Server"
    installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
    ./$installFile --mode unattended --dbLicenseAcceptance accept --installmongodb true --dbhost $schedulerDatabaseHost --mongodir $schedulerDatabasePath --prefix $schedulerInstallRoot
    mv /tmp/*_installer.log ./deadline-log-repository.txt
    cp $schedulerDatabasePath/certs/$schedulerCertificateFile $schedulerInstallRoot/$schedulerCertificateFile
    chmod +r $schedulerInstallRoot/$schedulerCertificateFile
    echo "$schedulerInstallRoot *(rw,no_root_squash)" >> /etc/exports
    exportfs -a
    echo "Customize (End): Deadline Server"
  else
    echo "Customize (Start): Deadline Client"
    installFile="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
    installArgs="--mode unattended --prefix $schedulerInstallRoot"
    if [ $machineType == "Scheduler" ]; then
      installArgs="$installArgs --slavestartup false --launcherdaemon false"
    else
      [ $machineType == "Farm" ] && workerStartup=true || workerStartup=false
      installArgs="$installArgs --slavestartup $workerStartup --launcherdaemon true"
    fi
    ./$installFile $installArgs
    mv /tmp/*_installer.log ./deadline-log-client.txt
    $schedulerBinPath/deadlinecommand -ChangeRepositorySkipValidation Direct $schedulerInstallRoot $schedulerCertificate ""
    echo "Customize (End): Deadline Client"
  fi
fi

if [[ $renderManager == *RoyalRender* ]]; then
  schedulerVersion="9.0.03"
  schedulerInstallRoot="/rr"
  schedulerBinPath="$schedulerInstallRoot/bin/lx64"
  binPaths="$binPaths:$schedulerBinPath"

  echo "Customize (Start): Royal Render Download"
  installFile="RoyalRender__${schedulerVersion}__installer.zip"
  downloadUrl="$storageContainerUrl/RoyalRender/$schedulerVersion/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  echo "Customize (End): Royal Render Download"

  echo "Customize (Start): Royal Render Installer"
  yum -y install fontconfig
  yum -y install xcb-util-wm
  yum -y install xcb-util-image
  yum -y install xcb-util-keysyms
  yum -y install xcb-util-renderutil
  yum -y install libxkbcommon
  yum -y install libxkbcommon-x11
  yum -y install qt5-qtbase
  yum -y install csh
  installType="royal-render"
  installFile="rrSetup_linux"
  installDirectory="RoyalRender*"
  chmod +x ./$installDirectory/$installFile
  mkdir $schedulerInstallRoot
  ./$installDirectory/$installFile -console -rrRoot $schedulerInstallRoot 1> "$installType.output.txt" 2> "$installType.error.txt"
  echo "Customize (End): Royal Render Installer"

  serviceUser="rrService"
  installFile="rrWorkstation_installer"
  useradd $serviceUser
  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Royal Render Server"
    $schedulerBinPath/$installFile -serviceServer -rrUser $serviceUser 1> "$installType-server.output.txt" 2> "$installType-server.error.txt"
    echo "$schedulerInstallRoot *(rw,no_root_squash)" >> /etc/exports
    exportfs -a
    echo "Customize (End): Royal Render Server"
  else
    echo "Customize (Start): Royal Render Client"
    $schedulerBinPath/$installFile -service -rrUser $serviceUser 1> "$installType-client.output.txt" 2> "$installType-client.error.txt"
    echo "Customize (End): Royal Render Client"
  fi
fi

if [[ $renderManager == *Qube* ]]; then
  schedulerVersion="7.5-2"
  schedulerConfigFile="/etc/qb.conf"
  schedulerInstallRoot="/usr/local/pfx/qube"
  schedulerBinPath="$schedulerInstallRoot/bin"
  binPaths="$binPaths:$schedulerBinPath:$schedulerInstallRoot/sbin"

  echo "Customize (Start): Qube Core"
  installType="qube-core"
  installFile="$installType-$schedulerVersion.CENTOS_7.8.x86_64.rpm"
  downloadUrl="$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  rpm -i $installType-*.rpm 1> "$installType.output.txt" 2> "$installType.error.txt"
  echo "Customize (End): Qube Core"

  yum -y install xinetd
  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Qube Supervisor"
    installType="qube-supervisor"
    installFile="$installType-${schedulerVersion}a.CENTOS_7.8.x86_64.rpm"
    downloadUrl="$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> "$installType.output.txt" 2> "$installType.error.txt"
    echo "Customize (End): Qube Supervisor"

    echo "Customize (Start): Qube Data Relay Agent (DRA)"
    installType="qube-dra"
    installFile="$installType-$schedulerVersion.CENTOS_7.8.x86_64.rpm"
    downloadUrl="$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> "$installType.output.txt" 2> "$installType.error.txt"
    echo "Customize (End): Qube Data Relay Agent (DRA)"
  else
    echo "Customize (Start): Qube Worker"
    installType="qube-worker"
    installFile="$installType-$schedulerVersion.CENTOS_7.8.x86_64.rpm"
    downloadUrl="$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> "$installType.output.txt" 2> "$installType.error.txt"
    echo "Customize (End): Qube Worker"

    echo "Customize (Start): Qube Client"
    installType="qube-client"
    installFile="$installType-$schedulerVersion.CENTOS_7.8.x86_64.rpm"
    downloadUrl="$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> "$installType.output.txt" 2> "$installType.error.txt"
    echo "Customize (End): Qube Client"

    sed -i "s/#qb_supervisor =/qb_supervisor = render.artist.studio/" $schedulerConfigFile
    sed -i "s/#worker_cpus = 0/worker_cpus = 1/" $schedulerConfigFile
  fi
fi

rendererPathPBRT="/usr/local/pbrt"
rendererPathBlender="/usr/local/blender"
rendererPathUnreal="/usr/local/unreal"

if [[ $renderEngines == *PBRT* ]]; then
  binPaths="$binPaths:$rendererPathPBRT"
fi
if [[ $renderEngines == *Blender* ]]; then
  binPaths="$binPaths:$rendererPathBlender"
fi
if [[ $renderEngines == *Unreal* ]]; then
  binPaths="$binPaths:$rendererPathUnreal"
fi
echo "PATH=$PATH$binPaths" > /etc/profile.d/aaa.sh

if [[ $renderEngines == *PBRT* ]]; then
  echo "Customize (Start): PBRT 3"
  versionInfo="v3"
  rendererPathPBRTv3="$rendererPathPBRT/$versionInfo"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git 1> "pbrt-$versionInfo-git.output.txt" 2> "pbrt-$versionInfo-git.error.txt"
  mkdir -p $rendererPathPBRTv3
  $binPathCMake/cmake -B $rendererPathPBRTv3 -S $binDirectory/pbrt-$versionInfo 1> "pbrt-$versionInfo-cmake.output.txt" 2> "pbrt-$versionInfo-cmake.error.txt"
  make -C $rendererPathPBRTv3 1> "pbrt-$versionInfo-make.output.txt" 2> "pbrt-$versionInfo-make.error.txt"
  ln -s $rendererPathPBRTv3/pbrt $rendererPathPBRT/pbrt3
  echo "Customize (End): PBRT 3"

  echo "Customize (Start): PBRT 4"
  yum -y install mesa-libGL-devel
  yum -y install libXrandr-devel
  yum -y install libXinerama-devel
  yum -y install libXcursor-devel
  yum -y install libXi-devel
  versionInfo="v4"
  rendererPathPBRTv4="$rendererPathPBRT/$versionInfo"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git 1> "pbrt-$versionInfo-git.output.txt" 2> "pbrt-$versionInfo-git.error.txt"
  mkdir -p $rendererPathPBRTv4
  $binPathCMake/cmake -B $rendererPathPBRTv4 -S $binDirectory/pbrt-$versionInfo 1> "pbrt-$versionInfo-cmake.output.txt" 2> "pbrt-$versionInfo-cmake.error.txt"
  make -C $rendererPathPBRTv4 1> "pbrt-$versionInfo-make.output.txt" 2> "pbrt-$versionInfo-make.error.txt"
  ln -s $rendererPathPBRTv4/pbrt $rendererPathPBRT/pbrt4
  echo "Customize (End): PBRT 4"
fi

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender 3.4"
  yum -y install libxkbcommon
  yum -y install libXxf86vm
  yum -y install libXfixes
  yum -y install libXrender
  yum -y install libXi
  yum -y install libGL
  versionInfo="3.4.1"
  versionType="linux-x64"
  installFile="blender-$versionInfo-$versionType.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xJf $installFile
  cd blender-$versionInfo-$versionType
  installDirectory="$rendererPathBlender/$versionInfo"
  mkdir -p $installDirectory
  mv * $installDirectory
  cd $binDirectory
  ln -s $installDirectory/blender $rendererPathBlender/blender3-4
  echo "Customize (End): Blender 3.4"

  echo "Customize (Start): Blender 3.5"
  yum -y install libSM
  versionInfo="3.5.0"
  versionType="alpha+master.09ba00974f8f-linux.x86_64-release"
  installFile="blender-$versionInfo-$versionType.tar.xz"
  downloadUrl="$storageContainerUrl/Blender/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xJf $installFile
  cd blender-$versionInfo-$versionType
  installDirectory="$rendererPathBlender/$versionInfo"
  mkdir -p $installDirectory
  mv * $installDirectory
  cd $binDirectory
  ln -s $installDirectory/blender $rendererPathBlender/blender3-5
  echo "Customize (End): Blender 3.5"
fi

if [[ $renderEngines == *Unreal* ]] || [[ $renderEngines == *Unreal.PixelStream* ]]; then
  echo "Customize (Start): Unreal Engine Setup"
  yum -y install libicu
  versionInfo="5.1.1"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$storageContainerUrl/Unreal/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  mkdir $rendererPathUnreal
  mv UnrealEngine-$versionInfo-release/* $rendererPathUnreal
  $rendererPathUnreal/Setup.sh 1> "unreal-engine-setup.output.txt" 2> "unreal-engine-setup.error.txt"
  echo "Customize (End): Unreal Engine Setup"

  echo "Customize (Start): Unreal Project Files Generate"
  $rendererPathUnreal/GenerateProjectFiles.sh 1> "unreal-project-files-generate.output.txt" 2> "unreal-project-files-generate.error.txt"
  echo "Customize (End): Unreal Project Files Generate"

  echo "Customize (Start): Unreal Engine Build"
  make -C $rendererPathUnreal 1> "unreal-engine-build.output.txt" 2> "unreal-engine-build.error.txt"
  echo "Customize (End): Unreal Engine Build"

  if [[ $renderEngines == *Unreal.PixelStream* ]]; then
    echo "Customize (Start): Unreal Pixel Streaming"
    git clone --recursive https://github.com/EpicGames/PixelStreamingInfrastructure --branch UE5.1 1> "unreal-stream-git.output.txt" 2> "unreal-stream-git.error.txt"
    yum -y install coturn
    installFile="PixelStreamingInfrastructure/SignallingWebServer/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 1> "unreal-stream-signalling.output.txt" 2> "unreal-stream-signalling.error.txt"
    installFile="PixelStreamingInfrastructure/Matchmaker/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 1> "unreal-stream-matchmaker.output.txt" 2> "unreal-stream-matchmaker.error.txt"
    installFile="PixelStreamingInfrastructure/SFU/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 1> "unreal-stream-sfu.output.txt" 2> "unreal-stream-sfu.error.txt"
    echo "Customize (End): Unreal Pixel Streaming"
  fi
fi

if [[ $renderEngines == *Unity* ]]; then
  echo "Customize (Start): Unity Hub"
  repoPath="/etc/yum.repos.d/unityhub.repo"
  echo "[unityhub]" > $repoPath
  echo "name=Unity Hub" >> $repoPath
  echo "baseurl=https://hub.unity3d.com/linux/repos/rpm/stable" >> $repoPath
  echo "enabled=1" >> $repoPath
  echo "gpgcheck=1" >> $repoPath
  echo "gpgkey=https://hub.unity3d.com/linux/repos/rpm/stable/repodata/repomd.xml.key" >> $repoPath
  echo "repo_gpgcheck=1" >> $repoPath
  yum -y install unityhub
  echo "Customize (End): Unity Hub"
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
  echo "Customize (Start): Desktop Environment"
  yum -y groups install "KDE Plasma Workspaces" 1> "kde.output.txt" 2> "kde.error.txt"
  echo "Customize (End): Desktop Environment"

  echo "Customize (Start): Teradici PCoIP"
  versionInfo="22.09.2"
  installFile="pcoip-agent-offline-centos7.9_$versionInfo-1.el7.x86_64.tar.gz"
  downloadUrl="$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  installDirectory="pcoip-agent"
  mkdir $installDirectory
  tar -xzf $installFile -C $installDirectory
  cd $installDirectory
  ./install-pcoip-agent.sh pcoip-agent-graphics usb-vhci 1> "$installDirectory.output.txt" 2> "$installDirectory.error.txt"
  cd $binDirectory
  echo "Customize (End): Teradici PCoIP"
fi
