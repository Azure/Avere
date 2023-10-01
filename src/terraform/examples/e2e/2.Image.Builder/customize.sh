#!/bin/bash -ex

binPaths=""
binDirectory="/usr/local/bin"
cd $binDirectory

aaaProfile="/etc/profile.d/aaa.sh"
touch $aaaProfile

source "/tmp/functions.sh"

echo "Customize (Start): Image Build Parameters"
dnf -y install jq
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
gpuProvider=$(echo $buildConfig | jq -r .gpuProvider)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
binStorageHost=$(echo $buildConfig | jq -r .binStorage.host)
binStorageAuth=$(echo $buildConfig | jq -r .binStorage.auth)
echo "Machine Type: $machineType"
echo "GPU Provider: $gpuProvider"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

echo "Customize (Start): Image Build Platform"
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
StartProcess "dnf -y install kernel-devel-$(uname -r)" $binDirectory/image-build-platform
StartProcess "dnf -y install gcc gcc-c++ python3-devel openssl-devel" $binDirectory/image-build-platform
StartProcess "dnf -y install perl cmake lsof git bc nfs-utils" $binDirectory/image-build-platform
if [ $machineType == Workstation ]; then
  echo "Customize (Start): Image Build Platform (Workstation)"
  StartProcess "dnf -y group install workstation" $binDirectory/image-build-platform-workstation
  StartProcess "dnf -y module install nodejs" $binDirectory/image-build-platform-nodejs
  echo "Customize (End): Image Build Platform (Workstation)"
fi
echo "Customize (End): Image Build Platform"

if [ $machineType == Storage ]; then
  echo "Customize (Start): NVIDIA OFED"
  dnf -y install kernel-rpm-macros rpm-build libtool gcc-gfortran pciutils tcl tk
  installFile="MLNX_OFED_LINUX-23.07-0.5.1.2-rhel9.2-x86_64.tgz"
  downloadUrl="$binStorageHost/NVIDIA/OFED/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  StartProcess "./MLNX_OFED*/mlnxofedinstall --without-fw-update --add-kernel-support --skip-repo --force" $binDirectory/mellanox-ofed
  echo "Customize (End): NVIDIA OFED"
fi

if [ "$gpuProvider" == NVIDIA ]; then
  echo "Customize (Start): NVIDIA GPU (GRID)"
  dnf -y install mesa-vulkan-drivers libglvnd-devel
  installType="nvidia-gpu-grid"
  installFile="$installType.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  StartProcess "./$installFile --silent" $binDirectory/$installType
  echo "Customize (End): NVIDIA GPU (GRID)"

  echo "Customize (Start): NVIDIA GPU (CUDA)"
  installType="nvidia-cuda"
  dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
  StartProcess "dnf -y install cuda" $binDirectory/$installType
  echo "Customize (End): NVIDIA GPU (CUDA)"

  echo "Customize (Start): NVIDIA OptiX"
  dnf -y install mesa-libGL
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  versionInfo="8.0.0"
  installType="nvidia-optix"
  installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64.sh"
  downloadUrl="$binStorageHost/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  installPath="$binDirectory/$installType/$versionInfo"
  mkdir -p $installPath
  StartProcess "./$installFile --skip-license --prefix=$installPath" $binDirectory/$installType
  buildDirectory="$installPath/build"
  mkdir -p $buildDirectory
  StartProcess "cmake -B $buildDirectory -S $installPath/SDK" $binDirectory/$installType-cmake
  StartProcess "make -C $buildDirectory" $binDirectory/$installType-make
  binPaths="$binPaths:$buildDirectory/bin"
  echo "Customize (End): NVIDIA OptiX"
fi

if [[ $machineType == Storage || $machineType == Scheduler ]]; then
  echo "Customize (Start): Azure CLI"
  installType="azure-cli"
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  dnf -y install https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
  StartProcess "dnf -y install $installType" $binDirectory/$installType
  echo "Customize (End): Azure CLI"
fi

if [[ $renderEngines == *PBRT* ]]; then
  echo "Customize (Start): PBRT"
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  dnf -y install libXi-devel
  versionInfo="v4"
  installType="pbrt"
  installPath="/usr/local/pbrt"
  mkdir -p $installPath
  StartProcess "git clone --recursive https://github.com/mmp/$installType-$versionInfo.git" $binDirectory/$installType-git
  StartProcess "cmake -B $installPath -S $binDirectory/$installType-$versionInfo" $binDirectory/$installType-cmake
  StartProcess "make -C $installPath" $binDirectory/$installType-make
  binPaths="$binPaths:$installPath"
  echo "Customize (End): PBRT"
fi

if [[ $renderEngines == *Blender* ]]; then
  echo "Customize (Start): Blender"
  dnf -y install mesa-libGL
  dnf -y install libXxf86vm
  dnf -y install libXfixes
  dnf -y install libXi
  dnf -y install libSM
  versionInfo="3.6.2"
  versionType="linux-x64"
  installType="blender"
  installPath="/usr/local/$installType"
  installFile="$installType-$versionInfo-$versionType.tar.xz"
  downloadUrl="$binStorageHost/Blender/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xJf $installFile
  mkdir -p $installPath
  mv $installType-$versionInfo-$versionType/* $installPath
  binPaths="$binPaths:$installPath"
  echo "Customize (End): Blender"
fi

if [[ $renderEngines == *Maya* ]]; then
  echo "Customize (Start): Maya"
  dnf -y install mesa-libGL
  dnf -y install mesa-libGLU
  dnf -y install alsa-lib
  dnf -y install libXxf86vm
  dnf -y install libXmu
  dnf -y install libXpm
  dnf -y install libnsl
  dnf -y install gtk3
  versionInfo="2024_0_1"
  installType="autodesk-maya"
  installFile="Autodesk_Maya_${versionInfo}_Update_Linux_64bit.tgz"
  downloadUrl="$binStorageHost/Maya/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir -p $installType
  tar -xzf $installFile -C $installType
  StartProcess "./$installType/Setup --silent" $binDirectory/$installType
  binPaths="$binPaths:/usr/autodesk/maya/bin"
  echo "Customize (End): Maya"
fi

if [[ $renderEngines == *Houdini* ]]; then
  echo "Customize (Start): Houdini"
  dnf -y install mesa-libGL
  dnf -y install libXcomposite
  dnf -y install libXdamage
  dnf -y install libXrandr
  dnf -y install libXcursor
  dnf -y install libXi
  dnf -y install libXtst
  dnf -y install libXScrnSaver
  dnf -y install alsa-lib
  dnf -y install libnsl
  dnf -y install avahi
  versionInfo="19.5.569"
  versionEULA="2021-10-13"
  installType="houdini"
  installFile="$installType-$versionInfo-linux_x86_64_gcc9.3.tar.gz"
  downloadUrl="$binStorageHost/Houdini/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  [[ $machineType == Workstation ]] && desktopMenus=--install-menus || desktopMenus=--no-install-menus
  [[ $renderEngines == *Maya* ]] && mayaPlugIn=--install-engine-maya || mayaPlugIn=--no-install-engine-maya
  [[ $renderEngines == *Unreal* ]] && unrealPlugIn=--install-engine-unreal || unrealPlugIn=--no-install-engine-unreal
  StartProcess "./houdini*/houdini.install --auto-install --make-dir --no-install-license --accept-EULA $versionEULA $desktopMenus $mayaPlugIn $unrealPlugIn" $binDirectory/$installType
  binPaths="$binPaths:/opt/hfs$versionInfo/bin"
  echo "Customize (End): Houdini"
fi

if [[ $renderEngines == *MoonRay* ]]; then
  echo "Customize (Start): MoonRay"
  installRoot="/moonray"
  installType="moonray"
  StartProcess "git clone --recurse-submodules https://github.com/dreamworksanimation/openmoonray.git $installRoot" $binDirectory/$installType-git
  StartProcess "source $installRoot/building/Rocky9/install_packages.sh" $binDirectory/$installType-packages
  cd $binDirectory

  echo "Customize (Start): MoonRay Build Prerequisites"

  echo "Customize (Start): MoonRay NVIDIA CUDA"
  StartProcess "dnf -y install cuda" $binDirectory/$installType-cuda
  echo "Customize (End): MoonRay NVIDIA CUDA"

  echo "Customize (Start): MoonRay NVIDIA OptiX"
  dnf -y install mesa-libGL
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  versionInfo="7.3.0"
  installType="moonray-nvidia-optix"
  installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64.sh"
  downloadUrl="$binStorageHost/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  installPath="$binDirectory/$installType/$versionInfo"
  mkdir -p $installPath
  StartProcess "./$installFile --skip-license --prefix=$installPath" $binDirectory/$installType
  buildDirectory="$installPath/build"
  mkdir -p $buildDirectory
  StartProcess "cmake -B $buildDirectory -S $installPath/SDK" $binDirectory/$installType-cmake
  StartProcess "make -C $buildDirectory" $binDirectory/$installType-make
  binPathOptiX="$installPath"
  echo "Customize (End): MoonRay NVIDIA OptiX"

  mkdir -p $installRoot/build
  cd $installRoot/build
  installType="moonray-prereq"
  StartProcess "cmake ../building/Rocky9" $binDirectory/$installType
  StartProcess "cmake --build . -- -j 64" $binDirectory/$installType-build

  echo "Customize (End): MoonRay Build Prerequisites"

  echo "Customize (Start): MoonRay Build"
  cd $installRoot/build
  rm -rf *
  installType="moonray"
  [[ $machineType == Workstation ]] && uiApps=YES || uiApps=NO
  StartProcess "cmake $installRoot -D PYTHON_EXECUTABLE=python3 -D BOOST_PYTHON_COMPONENT_NAME=python39 -D ABI_VERSION=0 -D OptiX_INCLUDE_DIRS=$binPathOptix/include -D BUILD_QT_APPS=$uiApps" $binDirectory/$installType
  StartProcess "cmake --build . -- -j 64" $binDirectory/$installType-build
  mkdir -p /installs$installRoot
  StartProcess "cmake --install $installRoot/build --prefix /installs$installRoot" $binDirectory/$installType-install
  echo "Customize (End): MoonRay Build"

  envSetupFile="/installs$installRoot/scripts/setup.sh"
  if [ FileExists $envSetupFile ]; then
    echo "source $envSetupFile" >> $aaaProfile
  fi
  cd $binDirectory
  echo "Customize (End): MoonRay"
fi

if [[ $renderEngines == *Unreal* ]] || [[ $renderEngines == *Unreal+PixelStream* ]]; then
  echo "Customize (Start): Unreal Engine Setup"
  dnf -y install libicu
  versionInfo="5.3.0"
  installType="unreal-engine"
  installPath="/usr/local/unreal"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$binStorageHost/Unreal/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  mkdir -p $installPath
  mv UnrealEngine-$versionInfo-release/* $installPath
  StartProcess "$installPath/Setup.sh" $binDirectory/$installType-setup
  echo "Customize (End): Unreal Engine Setup"

  echo "Customize (Start): Unreal Project Files Generate"
  StartProcesss "$installPath/GenerateProjectFiles.sh" $binDirectory/unreal-project-files-generate
  echo "Customize (End): Unreal Project Files Generate"

  echo "Customize (Start): Unreal Engine Build"
  StartProcess "make -C $installPath" $binDirectory/$installType-make
  echo "Customize (End): Unreal Engine Build"

  if [[ $renderEngines == *Unreal+PixelStream* ]]; then
    echo "Customize (Start): Unreal Pixel Streaming"
    dnf -y install coturn
    versionInfo="5.3-0.0.3"
    installType="unreal-stream"
    installFile="UE$versionInfo.tar.gz"
    downloadUrl="$binStorageHost/Unreal/PixelStream/$versionInfo/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    tar -xzf $installFile
    installFile="PixelStreamingInfrastructure-UE$versionInfo/SignallingWebServer/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    StartProcess "./$installFile" $binDirectory/$installType-signalling
    installFile="PixelStreamingInfrastructure-UE$versionInfo/Matchmaker/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    StartProcess "./$installFile" $binDirectory/$installType-matchmaker
    installFile="PixelStreamingInfrastructure-UE$versionInfo/SFU/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    StartProcess "./$installFile" $binDirectory/$installType-sfu
    echo "Customize (End): Unreal Pixel Streaming"
  fi

  binPaths="$binPaths:$installPath/Engine/Binaries/Linux"
fi

if [ $machineType == Scheduler ]; then
  echo "Customize (Start): NFS Server"
  systemctl --now enable nfs-server
  echo "Customize (End): NFS Server"
fi

if [ $machineType != Storage ]; then
  versionInfo="10.3.0.9"
  installRoot="/Deadline"
  serverMount="/DeadlineServer"
  databaseHost=$(hostname)
  databasePort=27017
  databaseName="deadline10db"
  binPathScheduler="$installRoot/bin"

  echo "Customize (Start): Deadline Download"
  installFile="Deadline-$versionInfo-linux-installers.tar"
  installPath=$(echo ${installFile%.tar})
  downloadUrl="$binStorageHost/Deadline/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir -p $installPath
  tar -xzf $installFile -C $installPath
  echo "Customize (End): Deadline Download"

  if [ $machineType == Scheduler ]; then
    echo "Customize (Start): Mongo DB Service"
    repoPath="/etc/yum.repos.d/mongodb.repo"
    echo "[mongodb-org-4.4]" > $repoPath
    echo "name=MongoDB 4.4" >> $repoPath
    echo "baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/4.4/x86_64/" >> $repoPath
    echo "gpgcheck=1" >> $repoPath
    echo "enabled=1" >> $repoPath
    echo "gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" >> $repoPath
    dnf -y install mongodb-org
    configFile="/etc/mongod.conf"
    sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" $configFile
    sed -i "/bindIp: 0.0.0.0/a\  tls:" $configFile
    sed -i "/tls:/a\    mode: disabled" $configFile
    sed -i "s/#security:/security:/" $configFile
    sed -i "/security:/a\  authorization: disabled" $configFile
    systemctl --now enable mongod
    sleep 5s
    echo "Customize (End): Mongo DB Service"

    echo "Customize (Start): Deadline Server"
    installFile="DeadlineRepository-$versionInfo-linux-x64-installer.run"
    $installPath/$installFile --mode unattended --dbLicenseAcceptance accept --prefix $installRoot --dbhost $databaseHost --dbport $databasePort --dbname $databaseName --dbauth false --installmongodb false
    mv /tmp/installbuilder_installer.log $binDirectory/deadline-repository.log
    chown -R root $installRoot
    chgrp -R root $installRoot
    echo "$installRoot *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -r
    echo "Customize (End): Deadline Server"
  fi

  echo "Customize (Start): Deadline Client"
  installFile="DeadlineClient-$versionInfo-linux-x64-installer.run"
  installArgs="--mode unattended --prefix $installRoot --repositorydir $serverMount"
  if [ $machineType == Scheduler ]; then
    installArgs="$installArgs --slavestartup false --launcherdaemon false"
  else
    [ $machineType == Farm ] && workerStartup=true || workerStartup=false
    installArgs="$installArgs --slavestartup $workerStartup --launcherdaemon true"
  fi
  $installPath/$installFile $installArgs
  cp /tmp/installbuilder_installer.log $binDirectory/deadline-client.log
  echo "Customize (End): Deadline Client"

  binPaths="$binPaths:$binPathScheduler"
fi

if [ $machineType == Workstation ]; then
  echo "Customize (Start): HP Anyware"
  versionInfo="23.08"
  [ "$gpuProvider" == "" ] && installType=pcoip-agent-standard || installType=pcoip-agent-graphics
  installFile="pcoip-agent-offline-rhel9.2_$versionInfo.2-1.el9.x86_64.tar.gz"
  downloadUrl="$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir -p $installType
  tar -xzf $installFile -C $installType
  cd $installType
  StartProcess "./install-pcoip-agent.sh $installType usb-vhci" $binDirectory/$installType
  cd $binDirectory
  echo "Customize (End): HP Anyware"
fi

if [ "$binPaths" != "" ]; then
  echo 'PATH=$PATH':$binPaths >> $aaaProfile
fi
