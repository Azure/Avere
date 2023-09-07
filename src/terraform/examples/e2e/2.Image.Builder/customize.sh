#!/bin/bash -ex

binPaths=""
binDirectory="/usr/local/bin"
cd $binDirectory

aaaProfile="/etc/profile.d/aaa.sh"
touch $aaaProfile

echo "Customize (Start): Image Build Parameters"
dnf -y install jq
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
gpuProvider=$(echo $buildConfig | jq -r .gpuProvider)
renderManager=$(echo $buildConfig | jq -r .renderManager)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
binStorageHost=$(echo $buildConfig | jq -r .binStorage.host)
binStorageAuth=$(echo $buildConfig | jq -r .binStorage.auth)
servicePassword=$(echo $buildConfig | jq -r .servicePassword)
echo "Machine Type: $machineType"
echo "GPU Provider: $gpuProvider"
echo "Render Manager: $renderManager"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

echo "Customize (Start): Image Build Platform"
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
dnf -y install gcc gcc-c++ perl bison flex elfutils-libelf-devel openssl-devel
installFile="kernel-devel-5.14.0-70.17.1.el9_0.x86_64.rpm"
downloadUrl="$binStorageHost/Linux/Rocky/$installFile$binStorageAuth"
curl -o $installFile -L $downloadUrl
rpm -i $installFile
dnf -y install epel-release python3-devel cmake lsof unzip git bc
if [ $machineType == Workstation ]; then
  dnf -y group install Workstation &> Workstation.log
  dnf -y module install nodejs:18
fi
echo "Customize (End): Image Build Platform"

if [ $machineType == Storage ]; then
  dnf -y install kernel-rpm-macros rpm-build python3-devel gcc-gfortran libtool pciutils tcl tk
  installFile="MLNX_OFED_LINUX-23.04-1.1.3.0-rhel9.0-x86_64.tgz"
  downloadUrl="$binStorageHost/NVIDIA/OFED/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  ./MLNX_OFED*/mlnxofedinstall --without-fw-update --add-kernel-support --skip-repo --force 2>&1 | tee mellanox-ofed.log
fi

if [[ $machineType == Storage || $machineType == Scheduler ]]; then
  echo "Customize (Start): Azure CLI"
  installType="azure-cli"
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  dnf -y install https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
  dnf -y install $installType 2>&1 | tee $installType.log
  echo "Customize (End): Azure CLI"
fi

if [ "$gpuProvider" == NVIDIA ]; then
  echo "Customize (Start): NVIDIA GPU (GRID)"
  dnf -y install mesa-vulkan-drivers libglvnd-devel
  installType="nvidia-gpu-grid"
  installFile="$installType.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent 2>&1 | tee $installType.log
  echo "Customize (End): NVIDIA GPU (GRID)"

  echo "Customize (Start): NVIDIA GPU (CUDA)"
  installType="nvidia-cuda"
  dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
  dnf -y install cuda 2>&1 | tee $installType.log
  echo "Customize (End): NVIDIA GPU (CUDA)"

  echo "Customize (Start): NVIDIA OptiX"
  dnf -y install mesa-libGL
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  versionInfo="7.3.0"
  installType="nvidia-optix"
  installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64.sh"
  downloadUrl="$binStorageHost/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  mkdir -p $installType
  ./$installFile --skip-license --prefix=$installType 2>&1 | tee $installType.log
  buildDirectory="$binDirectory/$installType/build"
  mkdir -p $buildDirectory
  cmake -B $buildDirectory -S $binDirectory/$installType/SDK 2>&1 | tee $installType-cmake.log
  make -C $buildDirectory 2>&1 | tee $installType-make.log
  binPaths="$binPaths:$buildDirectory/bin"
  echo "Customize (End): NVIDIA OptiX"
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
  ./$installType/Setup --silent 2>&1 | tee $installType.log
  binPaths="$binPaths:/usr/autodesk/maya/bin"
  echo "Customize (End): Maya"
fi

if [[ $renderEngines == *PBRT* ]]; then
  installPath="/usr/local/pbrt"

  # echo "Customize (Start): PBRT v3"
  # versionInfo="v3"
  # installType="pbrt-$versionInfo"
  # installPathV3="$installPath/$versionInfo"
  # git clone --recursive https://github.com/mmp/$installType.git 2>&1 | tee $installType-git.log
  # mkdir -p $installPathV3
  # cmake -B $installPathV3 -S $binDirectory/$installType 2>&1 | tee $installType-cmake.log
  # make -C $installPathV3 2>&1 | tee $installType-make.log
  # ln -s $installPathV3/pbrt $installPath/pbrt3
  # echo "Customize (End): PBRT v3"

  echo "Customize (Start): PBRT v4"
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  dnf -y install libXi-devel
  versionInfo="v4"
  installType="pbrt-$versionInfo"
  installPathV4="$installPath/$versionInfo"
  git clone --recursive https://github.com/mmp/$installType.git 2>&1 | tee $installType-git.log
  mkdir -p $installPathV4
  cmake -B $installPathV4 -S $binDirectory/$installType 2>&1 | tee $installType-cmake.log
  make -C $installPathV4 2>&1 | tee $installType-make.log
  ln -s $installPathV4/pbrt $installPath/pbrt4
  echo "Customize (End): PBRT v4"

  binPaths="$binPaths:$installPath"
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
  ./houdini*/houdini.install --auto-install --make-dir --no-install-license --accept-EULA $versionEULA $desktopMenus $mayaPlugIn $unrealPlugIn 2>&1 | tee $installType.log
  binPaths="$binPaths:/opt/hfs$versionInfo/bin"
  echo "Customize (End): Houdini"
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

if [[ $renderEngines == *Unreal* ]] || [[ $renderEngines == *Unreal+PixelStream* ]]; then
  echo "Customize (Start): Unreal Engine Setup"
  dnf -y install libicu
  versionInfo="5.2.1"
  installType="unreal-engine"
  installPath="/usr/local/unreal"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$binStorageHost/Unreal/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  mkdir -p $installPath
  mv UnrealEngine-$versionInfo-release/* $installPath
  $installPath/Setup.sh 2>&1 | tee $installType-setup.log
  echo "Customize (End): Unreal Engine Setup"

  echo "Customize (Start): Unreal Project Files Generate"
  $installPath/GenerateProjectFiles.sh 2>&1 | tee unreal-project-files-generate.log
  echo "Customize (End): Unreal Project Files Generate"

  echo "Customize (Start): Unreal Engine Build"
  make -C $installPath 2>&1 | tee $installType-make.log
  echo "Customize (End): Unreal Engine Build"

  if [[ $renderEngines == *Unreal+PixelStream* ]]; then
    echo "Customize (Start): Unreal Pixel Streaming"
    dnf -y install coturn
    versionInfo="5.2-0.6.5"
    installType="unreal-stream"
    installFile="UE$versionInfo.tar.gz"
    downloadUrl="$binStorageHost/Unreal/PixelStream/$versionInfo/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    tar -xzf $installFile
    installFile="PixelStreamingInfrastructure-UE$versionInfo/SignallingWebServer/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 2>&1 | tee $installType-signalling.log
    installFile="PixelStreamingInfrastructure-UE$versionInfo/Matchmaker/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 2>&1 | tee $installType-matchmaker.log
    installFile="PixelStreamingInfrastructure-UE$versionInfo/SFU/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile 2>&1 | tee $installType-sfu.log
    echo "Customize (End): Unreal Pixel Streaming"
  fi

  binPaths="$binPaths:$installPath/Engine/Binaries/Linux"
fi

if [[ $renderEngines == *MoonRay* ]]; then
  echo "Customize (Start): MoonRay"
  git clone --recurse-submodules https://github.com/dreamworksanimation/openmoonray.git /openmoonray
  source /openmoonray/building/Rocky9/install_packages.sh

  mkdir -p /openmoonray/build
  cd /openmoonray/build
  installType="openmoonray-prereq"
  cmake ../building/Rocky9 &> $installType.log
  cmake --build . -- -j 64 &> $installType-build.log

  cd /openmoonray/build
  rm -rf *
  installType="openmoonray"
  [[ "$gpuProvider" == NVIDIA ]] && useCUDA=YES || useCUDA=NO
  [[ $machineType == Workstation ]] && uiApps=YES || uiApps=NO
  cmake /openmoonray -D PYTHON_EXECUTABLE=python3 -D BOOST_PYTHON_COMPONENT_NAME=python39 -D ABI_VERSION=0 -D OptiX_INCLUDE_DIRS=/usr/local/bin/nvidia-optix/include -D MOONRAY_USE_CUDA=$useCUDA -D BUILD_QT_APPS=$uiApps &> $installType.log
  cmake --build . -- -j 64 &> $installType-build.log
  mkdir -p /installs/openmoonray
  cmake --install /openmoonray/build --prefix /installs/openmoonray &> $installType-install.log
  echo "source /installs/openmoonray/scripts/setup.sh" >> $aaaProfile
  cd $binDirectory
  echo "Customize (End): MoonRay"
fi

if [[ $machineType == Scheduler && ($renderManager == *Deadline* || $renderManager == *RoyalRender*) ]]; then
  echo "Customize (Start): NFS Server"
  systemctl --now enable nfs-server
  echo "Customize (End): NFS Server"
fi

if [[ $renderManager == *Deadline* ]]; then
  versionInfo="10.3.0.9"
  installRoot="/Deadline"
  serverMount="/DeadlineServer"
  databaseHost=$(hostname)
  databasePort=27017
  databaseUser="dbService"
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
    systemctl --now enable mongod
    sleep 10s
    echo "Customize (End): Mongo DB Service"

    echo "Customize (Start): Mongo DB User"
    installType="mongo-create-user"
    createUserScript="$installType.js"
    echo "db = db.getSiblingDB(\"$databaseName\");" > $createUserScript
    echo "db.createUser({" >> $createUserScript
    echo "user: \"$databaseUser\"," >> $createUserScript
    echo "pwd: \"$servicePassword\"," >> $createUserScript
    echo "roles: [" >> $createUserScript
    echo "{ role: \"dbOwner\", db: \"$databaseName\" }" >> $createUserScript
    echo "]})" >> $createUserScript
    mongo $createUserScript 2>&1 | tee $installType.log
    if grep --silent --ignore-case exception $installType.log; then
      exit 1
    fi
    echo "Customize (End): Mongo DB User"

    echo "Customize (Start): Deadline Server"
    export DB_PASSWORD=$servicePassword
    installFile="DeadlineRepository-$versionInfo-linux-x64-installer.run"
    $installPath/$installFile --mode unattended --dbLicenseAcceptance accept --prefix $installRoot --dbhost $databaseHost --dbport $databasePort --dbname $databaseName --installmongodb false --dbauth true --dbuser $databaseUser --dbpassword env:DB_PASSWORD
    mv /tmp/installbuilder_installer.log $binDirectory/deadline-repository.log
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
  echo "$binPathScheduler/deadlinecommand -StoreDatabaseCredentials $databaseUser $servicePassword" >> $aaaProfile
  echo "Customize (End): Deadline Client"

  binPaths="$binPaths:$binPathScheduler"
fi

if [[ $renderManager == *RoyalRender* ]]; then
  versionInfo="9.0.08"
  installRoot="/RoyalRender"
  binPathScheduler="$installRoot/bin/lx64"

  echo "Customize (Start): Royal Render Download"
  installFile="RoyalRender__${versionInfo}__installer.zip"
  downloadUrl="$binStorageHost/RoyalRender/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  echo "Customize (End): Royal Render Download"

  dnf -y install fontconfig
  dnf -y install xcb-util-wm
  dnf -y install xcb-util-image
  dnf -y install xcb-util-keysyms
  dnf -y install xcb-util-renderutil
  dnf -y install libxkbcommon-x11
  if [ $machineType == Scheduler ]; then
    echo "Customize (Start): Royal Render Server"
    installPath="RoyalRender*"
    installFile="rrSetup_linux"
    chmod +x ./$installPath/$installFile
    mkdir -p $installRoot
    ./$installPath/$installFile -console -rrRoot $installRoot 2>&1 | tee royal-render.log
    echo "$installRoot *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -r
    echo "Customize (End): Royal Render Server"
  fi

  binPaths="$binPaths:$binPathScheduler"
fi

if [ $machineType == Workstation ]; then
  echo "Customize (Start): Teradici PCoIP"
  versionInfo="23.06"
  [ "$gpuProvider" == "" ] && installType=pcoip-agent-standard || installType=pcoip-agent-graphics
  installFile="pcoip-agent-offline-rocky8.8_23.06.3-1.el8.x86_64.tar.gz"
  downloadUrl="$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir -p $installType
  tar -xzf $installFile -C $installType
  cd $installType
  ./install-pcoip-agent.sh $installType usb-vhci 2>&1 | tee ../$installType.log
  cd $binDirectory
  echo "Customize (End): Teradici PCoIP"
fi

if [ "$binPaths" != "" ]; then
  echo 'PATH=$PATH':$binPaths >> $aaaProfile
fi