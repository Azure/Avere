#!/bin/bash -ex

binPaths=""
binDirectory="/usr/local/bin"
cd $binDirectory

echo "Customize (Start): Image Build Parameters"
dnf -y install jq
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
gpuPlatform=$(echo $buildConfig | jq -c .gpuPlatform)
renderManager=$(echo $buildConfig | jq -r .renderManager)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
binStorageHost=$(echo $buildConfig | jq -r .binStorageHost)
binStorageAuth=$(echo $buildConfig | jq -r .binStorageAuth)
echo "Machine Type: $machineType"
echo "GPU Platform: $gpuPlatform"
echo "Render Manager: $renderManager"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

echo "Customize (Start): Image Build Platform"
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
#dnf -y install epel-release
#dnf -y install dkms
dnf -y install gcc gcc-c++
dnf -y install unzip
dnf -y install cmake
dnf -y install make
dnf -y install git
echo "Customize (End): Image Build Platform"

if [[ $gpuPlatform == *GRID* ]]; then
  echo "Customize (Start): NVIDIA GPU (GRID)"
  dnf -y install kernel-devel-$(uname -r)
  installType="nvidia-gpu-grid"
  installFile="$installType.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent 1> $installType.out.log 2> $installType.err.log
  #./$installFile --silent --dkms 1> $installType.out.log 2> $installType.err.log
  echo "Customize (End): NVIDIA GPU (GRID)"
fi

if [[ $gpuPlatform == *CUDA* ]] || [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA GPU (CUDA)"
  installType="nvidia-cuda"
  dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
  #dnf -y module install nvidia-driver:latest-dkms 1> $installType-dkms.out.log 2> $installType-dkms.err.log
  dnf -y install cuda 1> $installType.out.log 2> $installType.err.log
  echo "Customize (End): NVIDIA GPU (CUDA)"
fi

if [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA OptiX"
  versionInfo="7.7.0"
  installType="nvidia-optix"
  installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64.sh"
  downloadUrl="$storageContainerUrl/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  mkdir $installType
  ./$installFile --skip-license --prefix=$binDirectory/$installType 1> $installType.out.log 2> $installType.err.log
  buildDirectory="$binDirectory/$installType/build"
  mkdir $buildDirectory
  cmake -B $buildDirectory -S $binDirectory/$installType/SDK 1> $installType-cmake.out.log 2> $installType-cmake.err.log
  make -C $buildDirectory 1> $installType-make.out.log 2> $installType-make.err.log
  binPaths="$binPaths:$buildDirectory/bin"
  echo "Customize (End): NVIDIA OptiX"
fi

rendererPathPBRT="/usr/local/pbrt"
rendererPathBlender="/usr/local/blender"
rendererPathUnreal="/usr/local/unreal"

if [[ $renderEngines == *PBRT* ]]; then
  echo "Customize (Start): PBRT v3"
  versionInfo="v3"
  installType="pbrt-$versionInfo"
  rendererPathPBRTv3="$rendererPathPBRT/$versionInfo"
  git clone --recursive https://github.com/mmp/$installType.git 1> $installType-git.out.log 2> $installType-git.err.log
  mkdir -p $rendererPathPBRTv3
  cmake -B $rendererPathPBRTv3 -S $binDirectory/$installType 1> $installType-cmake.out.log 2> $installType-cmake.err.log
  make -C $rendererPathPBRTv3 1> $installType-make.out.log 2> $installType-make.err.log
  ln -s $rendererPathPBRTv3/pbrt $rendererPathPBRT/pbrt3
  echo "Customize (End): PBRT v3"

  echo "Customize (Start): PBRT v4"
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  dnf -y install libXi-devel
  versionInfo="v4"
  installType="pbrt-$versionInfo"
  rendererPathPBRTv4="$rendererPathPBRT/$versionInfo"
  git clone --recursive https://github.com/mmp/$installType.git 1> $installType-git.out.log 2> $installType-git.err.log
  mkdir -p $rendererPathPBRTv4
  cmake -B $rendererPathPBRTv4 -S $binDirectory/$installType 1> $installType-cmake.out.log 2> $installType-cmake.err.log
  make -C $rendererPathPBRTv4 1> $installType-make.out.log 2> $installType-make.err.log
  ln -s $rendererPathPBRTv4/pbrt $rendererPathPBRT/pbrt4
  echo "Customize (End): PBRT v4"

  binPaths="$binPaths:$rendererPathPBRT"
fi

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender"
  dnf -y install mesa-libGL
  dnf -y install libXxf86vm
  dnf -y install libXfixes
  dnf -y install libXi
  dnf -y install libSM
  versionInfo="3.5.0"
  versionType="linux-x64"
  installFile="blender-$versionInfo-$versionType.tar.xz"
  downloadUrl="$binStorageHost/Blender/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xf $installFile --xz
  mkdir -p $rendererPathBlender
  mv blender-$versionInfo-$versionType/* $rendererPathBlender
  binPaths="$binPaths:$rendererPathBlender"
  echo "Customize (End): Blender"
fi

if [[ $renderEngines == *Unreal* ]] || [[ $renderEngines == *Unreal.PixelStream* ]]; then
  echo "Customize (Start): Unreal Engine Setup"
  dnf -y install libicu
  versionInfo="5.1.1"
  installType="unreal-engine"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$binStorageHost/Unreal/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  mkdir $rendererPathUnreal
  mv UnrealEngine-$versionInfo-release/* $rendererPathUnreal
  $rendererPathUnreal/Setup.sh 1> $installType-setup.out.log 2> $installType-setup.err.log
  echo "Customize (End): Unreal Engine Setup"

  echo "Customize (Start): Unreal Project Files Generate"
  $rendererPathUnreal/GenerateProjectFiles.sh 1> unreal-project-files-generate.out.log 2> unreal-project-files-generate.err.log
  echo "Customize (End): Unreal Project Files Generate"

  echo "Customize (Start): Unreal Engine Build"
  make -C $rendererPathUnreal 1> $installType-build.out.log 2> $installType-build.err.log
  echo "Customize (End): Unreal Engine Build"

  if [[ $renderEngines == *Unreal.PixelStream* ]]; then
    echo "Customize (Start): Unreal Pixel Streaming"
    installType="unreal-stream"
    git clone --recursive https://github.com/EpicGames/PixelStreamingInfrastructure --branch UE5.1 1> $installType-git.out.log 2> $installType-git.err.log
    dnf -y install coturn
    installFile="PixelStreamingInfrastructure/SignallingWebServer/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 1> $installType-signalling.out.log 2> $installType-signalling.err.log
    installFile="PixelStreamingInfrastructure/Matchmaker/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 1> $installType-matchmaker.out.log 2> $installType-matchmaker.err.log
    installFile="PixelStreamingInfrastructure/SFU/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 1> $installType-sfu.out.log 2> $installType-sfu.err.log
    echo "Customize (End): Unreal Pixel Streaming"
  fi
  binPaths="$binPaths:$rendererPathUnreal"
fi

if [ $machineType == "Scheduler" ]; then
  echo "Customize (Start): Azure CLI"
  installType="az-cli"
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  dnf -y install https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
  dnf -y install azure-cli 1> $installType.out.log 2> $installType.err.log
  echo "Customize (End): Azure CLI"

  if [[ $renderManager == *RoyalRender* || $renderManager == *Deadline* ]]; then
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
  dnf -y install java-1.8.0-openjdk
  JAVA_HOME=/bin/java
  dnf -y install cyclecloud8
  cd /opt/cycle_server
  unzip -q ./tools/cyclecloud-cli.zip
  ./cyclecloud-cli-installer/install.sh --installdir $cycleCloudPath
  cd $binDirectory
  binPaths="$binPaths:$cycleCloudPath/bin"
  echo "Customize (End): CycleCloud"
fi

if [[ $renderManager == *RoyalRender* ]]; then
  schedulerVersion="9.0.04"
  schedulerInstallRoot="/RoyalRender"
  schedulerBinPath="$schedulerInstallRoot/bin/lx64"
  binPaths="$binPaths:$schedulerBinPath"

  echo "Customize (Start): Royal Render Download"
  installFile="RoyalRender__${schedulerVersion}__installer.zip"
  downloadUrl="$binStorageHost/RoyalRender/$schedulerVersion/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  echo "Customize (End): Royal Render Download"

  echo "Customize (Start): Royal Render Installer"
  dnf -y install xcb-util-wm
  dnf -y install xcb-util-image
  dnf -y install xcb-util-keysyms
  dnf -y install xcb-util-renderutil
  dnf -y install libxkbcommon-x11
  installType="royal-render"
  installPath="RoyalRender*"
  installFile="rrSetup_linux"
  chmod +x ./$installPath/$installFile
  mkdir $schedulerInstallRoot
  ./$installPath/$installFile -console -rrRoot $schedulerInstallRoot 1> $installType.out.log 2> $installType.err.log
  echo "Customize (End): Royal Render Installer"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Royal Render Server"
    echo "$schedulerInstallRoot *(rw,no_root_squash)" >> /etc/exports
    exportfs -a
    echo "Customize (End): Royal Render Server"
  fi
fi

if [[ $renderManager == *Qube* ]]; then
  schedulerVersion="8.0-0"
  schedulerConfigFile="/etc/qb.conf"
  schedulerInstallRoot="/usr/local/pfx/qube"
  schedulerBinPath="$schedulerInstallRoot/bin"
  binPaths="$binPaths:$schedulerBinPath:$schedulerInstallRoot/sbin"

  echo "Customize (Start): Qube Core"
  dnf -y install perl
  dnf -y install xinetd
  installType="qube-core"
  installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
  downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  rpm -i $installType-*.rpm 1> $installType.out.log 2> $installType.err.log
  echo "Customize (End): Qube Core"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Qube Supervisor"
    installType="qube-supervisor"
    installFile="$installType-${schedulerVersion}.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> $installType.out.log 2> $installType.err.log
    echo "Customize (End): Qube Supervisor"

    echo "Customize (Start): Qube Data Relay Agent (DRA)"
    installType="qube-dra"
    installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> $installType.out.log 2> $installType.err.log
    echo "Customize (End): Qube Data Relay Agent (DRA)"
  else
    echo "Customize (Start): Qube Worker"
    installType="qube-worker"
    installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> $installType.out.log 2> $installType.err.log
    echo "Customize (End): Qube Worker"

    echo "Customize (Start): Qube Client"
    installType="qube-client"
    installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm 1> $installType.out.log 2> $installType.err.log
    echo "Customize (End): Qube Client"

    sed -i "s/#qb_supervisor =/qb_supervisor = scheduler.content.studio/" $schedulerConfigFile
    sed -i "s/#worker_cpus = 0/worker_cpus = 1/" $schedulerConfigFile
  fi
fi

if [[ $renderManager == *Deadline* ]]; then
  schedulerVersion="10.2.1.0"
  schedulerInstallRoot="/Deadline"
  schedulerDatabaseHost=$(hostname)
  schedulerDatabasePath="/DeadlineDatabase"
  schedulerCertificateFile="Deadline10Client.pfx"
  schedulerCertificate="$schedulerInstallRoot/$schedulerCertificateFile"
  schedulerBinPath="$schedulerInstallRoot/bin"
  binPaths="$binPaths:$schedulerBinPath"

  echo "Customize (Start): Deadline Download"
  installFile="Deadline-$schedulerVersion-linux-installers.tar"
  installPath=$(echo $installFile | cut -d"." -f1,2,3,4)
  downloadUrl="$binStorageHost/Deadline/$schedulerVersion/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir $installPath
  tar -xzf $installFile -C $installPath
  echo "Customize (End): Deadline Download"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Deadline Server"
    installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
    $installPath/$installFile --mode unattended --dbLicenseAcceptance accept --installmongodb true --dbhost $schedulerDatabaseHost --mongodir $schedulerDatabasePath --prefix $schedulerInstallRoot
    mv -f /tmp/installbuilder_installer.log $binDirectory/deadline-repository.log
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
    $installPath/$installFile $installArgs
    mv -f /tmp/installbuilder_installer.log $binDirectory/deadline-client.log
    $schedulerBinPath/deadlinecommand -ChangeRepositorySkipValidation Direct $schedulerInstallRoot $schedulerCertificate ""
    echo "Customize (End): Deadline Client"
  fi
fi

echo "PATH=$PATH$binPaths" > /etc/profile.d/aaa.sh

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
  echo "Customize (Start): Teradici PCoIP"
  versionInfo="23.01.1"
  [[ $gpuPlatform == *GRID* ]] && installType=pcoip-agent-graphics || installType=pcoip-agent-standard
  installFile="pcoip-agent-offline-rocky8.6_$versionInfo-1.el8.x86_64.tar.gz"
  downloadUrl="$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir $installType
  tar -xzf $installFile -C $installType
  cd $installType
  ./install-pcoip-agent.sh $installType usb-vhci 1> ../$installType.out.log 2> ../$installType.err.log
  cd $binDirectory
  echo "Customize (End): Teradici PCoIP"
fi
