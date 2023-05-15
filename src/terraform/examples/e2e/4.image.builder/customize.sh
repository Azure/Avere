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
gpuPlatform=$(echo $buildConfig | jq -c .gpuPlatform)
renderManager=$(echo $buildConfig | jq -r .renderManager)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
binStorageHost=$(echo $buildConfig | jq -r .binStorageHost)
binStorageAuth=$(echo $buildConfig | jq -r .binStorageAuth)
servicePassword=$(echo $buildConfig | jq -r .servicePassword)
echo "Machine Type: $machineType"
echo "GPU Platform: $gpuPlatform"
echo "Render Manager: $renderManager"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

echo "Customize (Start): Image Build Platform"
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
dnf -y install epel-release
dnf -y install dkms
dnf -y install gcc gcc-c++
dnf -y install unzip
dnf -y install cmake
dnf -y install lsof
dnf -y install git
dnf -y install bc
echo "Customize (End): Image Build Platform"

if [[ $gpuPlatform == *GRID* ]]; then
  echo "Customize (Start): NVIDIA GPU (GRID)"
  dnf -y install kernel-devel-$(uname -r)
  installType="nvidia-gpu-grid"
  installFile="$installType.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile --silent --dkms &> $installType.log
  echo "Customize (End): NVIDIA GPU (GRID)"
fi

if [[ $gpuPlatform == *CUDA* ]] || [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA GPU (CUDA)"
  installType="nvidia-cuda"
  dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
  dnf -y module install nvidia-driver:latest-dkms &> $installType-dkms.log
  dnf -y install cuda &> $installType.log
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
  mkdir -p $installType
  ./$installFile --skip-license --prefix=$binDirectory/$installType &> $installType.log
  buildDirectory="$binDirectory/$installType/build"
  mkdir -p $buildDirectory
  cmake -B $buildDirectory -S $binDirectory/$installType/SDK &> $installType-cmake.log
  make -C $buildDirectory &> $installType-make.log
  binPaths="$binPaths:$buildDirectory/bin"
  echo "Customize (End): NVIDIA OptiX"
fi

if [ $machineType == "Scheduler" ]; then
  echo "Customize (Start): Azure CLI"
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  dnf -y install https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
  dnf -y install azure-cli &> azure-cli.log
  echo "Customize (End): Azure CLI"

  if [[ $renderManager == *Deadline* || $renderManager == *RoyalRender* ]]; then
    echo "Customize (Start): NFS Server"
    systemctl --now enable nfs-server
    echo "Customize (End): NFS Server"
  fi
fi

if [[ $renderManager == *Deadline* ]]; then
  schedulerVersion="10.2.1.0"
  schedulerInstallPath="/Deadline"
  schedulerServerMount="/DeadlineServer"
  schedulerDatabaseHost=$(hostname)
  schedulerDatabasePort=27017
  schedulerDatabaseUser="dbService"
  schedulerDatabaseName="deadline10db"
  schedulerBinPath="$schedulerInstallPath/bin"

  echo "Customize (Start): Deadline Download"
  installFile="Deadline-$schedulerVersion-linux-installers.tar"
  installPath=$(echo ${installFile%.tar})
  downloadUrl="$binStorageHost/Deadline/$schedulerVersion/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir -p $installPath
  tar -xzf $installFile -C $installPath
  echo "Customize (End): Deadline Download"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Mongo DB Service"
    repoPath="/etc/yum.repos.d/mongodb.repo"
    echo "[mongodb-org-4.4]" > $repoPath
    echo "name=MongoDB 4.4" >> $repoPath
    echo "baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/4.4/x86_64/" >> $repoPath
    echo "gpgcheck=1" >> $repoPath
    echo "enabled=1" >> $repoPath
    echo "gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" >> $repoPath
    dnf -y install mongodb-org
    serviceConfigFile="/etc/mongod.conf"
    sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" $serviceConfigFile
    sed -i "/bindIp: 0.0.0.0/a\  tls:" $serviceConfigFile
    sed -i "/tls:/a\    mode: disabled" $serviceConfigFile
    systemctl --now enable mongod
    sleep 5s
    echo "Customize (End): Mongo DB Service"

    echo "Customize (Start): Mongo DB User"
    installType="mongo-create-user"
    createUserScript="$installType.js"
    echo "db = db.getSiblingDB(\"$schedulerDatabaseName\");" > $createUserScript
    echo "db.createUser({" >> $createUserScript
    echo "user: \"$schedulerDatabaseUser\"," >> $createUserScript
    echo "pwd: \"$servicePassword\"," >> $createUserScript
    echo "roles: [" >> $createUserScript
    echo "{ role: \"dbOwner\", db: \"$schedulerDatabaseName\" }" >> $createUserScript
    echo "]})" >> $createUserScript
    mongo $createUserScript &> $installType.log
    echo "Customize (End): Mongo DB User"

    echo "Customize (Start): Deadline Server"
    export DB_PASSWORD=$servicePassword
    installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
    $installPath/$installFile --mode unattended --dbLicenseAcceptance accept --prefix $schedulerInstallPath --dbhost $schedulerDatabaseHost --dbport $schedulerDatabasePort --dbname $schedulerDatabaseName --installmongodb false --dbauth true --dbuser $schedulerDatabaseUser --dbpassword env:DB_PASSWORD
    mv /tmp/installbuilder_installer.log $binDirectory/deadline-repository.log
    echo "$schedulerInstallPath *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -r
    echo "Customize (End): Deadline Server"
  fi

  echo "Customize (Start): Deadline Client"
  installFile="DeadlineClient-$schedulerVersion-linux-x64-installer.run"
  installArgs="--mode unattended --prefix $schedulerInstallPath --repositorydir $schedulerServerMount"
  if [ $machineType == "Scheduler" ]; then
    installArgs="$installArgs --slavestartup false --launcherdaemon false"
  else
    [ $machineType == "Farm" ] && workerStartup=true || workerStartup=false
    installArgs="$installArgs --slavestartup $workerStartup --launcherdaemon true"
  fi
  $installPath/$installFile $installArgs
  cp /tmp/installbuilder_installer.log $binDirectory/deadline-client.log
  echo "$schedulerBinPath/deadlinecommand -StoreDatabaseCredentials $schedulerDatabaseUser $servicePassword" >> $aaaProfile
  echo "Customize (End): Deadline Client"

  binPaths="$binPaths:$schedulerBinPath"
fi

if [[ $renderManager == *RoyalRender* ]]; then
  schedulerVersion="9.0.04"
  schedulerInstallPath="/RoyalRender"
  schedulerBinPath="$schedulerInstallPath/bin/lx64"

  echo "Customize (Start): Royal Render Download"
  installFile="RoyalRender__${schedulerVersion}__installer.zip"
  downloadUrl="$binStorageHost/RoyalRender/$schedulerVersion/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  unzip -q $installFile
  echo "Customize (End): Royal Render Download"

  dnf -y install xcb-util-wm
  dnf -y install xcb-util-image
  dnf -y install xcb-util-keysyms
  dnf -y install xcb-util-renderutil
  dnf -y install libxkbcommon-x11
  installPath="RoyalRender*"
  installFile="rrSetup_linux"
  chmod +x ./$installPath/$installFile
  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Royal Render Server"
    mkdir -p $schedulerInstallPath
    ./$installPath/$installFile -console -rrRoot $schedulerInstallPath &> royal-render.log
    echo "$schedulerInstallPath *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -r
    echo "Customize (End): Royal Render Server"
  fi

  binPaths="$binPaths:$schedulerBinPath"
fi

if [[ $renderManager == *Qube* ]]; then
  schedulerVersion="8.0-0"
  schedulerConfigFile="/etc/qb.conf"
  schedulerInstallPath="/usr/local/pfx/qube"
  schedulerBinPath="$schedulerInstallPath/bin"

  echo "Customize (Start): Qube Core"
  dnf -y install perl
  dnf -y install xinetd
  installType="qube-core"
  installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
  downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  rpm -i $installType-*.rpm &> $installType.log
  echo "Customize (End): Qube Core"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): Qube Supervisor"
    installType="qube-supervisor"
    installFile="$installType-${schedulerVersion}.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm &> $installType.log
    echo "Customize (End): Qube Supervisor"

    echo "Customize (Start): Qube Data Relay Agent (DRA)"
    installType="qube-dra"
    installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm &> $installType.log
    echo "Customize (End): Qube Data Relay Agent (DRA)"
  else
    echo "Customize (Start): Qube Worker"
    installType="qube-worker"
    installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm &> $installType.log
    echo "Customize (End): Qube Worker"

    echo "Customize (Start): Qube Client"
    installType="qube-client"
    installFile="$installType-$schedulerVersion.CENTOS_8.2.x86_64.rpm"
    downloadUrl="$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    curl -o $installFile -L $downloadUrl
    rpm -i $installType-*.rpm &> $installType.log
    echo "Customize (End): Qube Client"

    sed -i "s/#qb_supervisor =/qb_supervisor = scheduler.content.studio/" $schedulerConfigFile
    sed -i "s/#worker_cpus = 0/worker_cpus = 1/" $schedulerConfigFile
  fi

  binPaths="$binPaths:$schedulerBinPath:$schedulerInstallPath/sbin"
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
  ./$installType/Setup --silent &> $installType.log
  binPaths="$binPaths:/usr/autodesk/maya/bin"
  echo "Customize (End): Maya"
fi

if [[ $renderEngines == *PBRT* ]]; then
  echo "Customize (Start): PBRT v3"
  versionInfo="v3"
  installType="pbrt-$versionInfo"
  installPath="/usr/local/pbrt"
  installPathV3="$installPath/$versionInfo"
  git clone --recursive https://github.com/mmp/$installType.git &> $installType-git.log
  mkdir -p $installPathV3
  cmake -B $installPathV3 -S $binDirectory/$installType &> $installType-cmake.log
  make -C $installPathV3 &> $installType-make.log
  ln -s $installPathV3/pbrt $installPath/pbrt3
  echo "Customize (End): PBRT v3"

  echo "Customize (Start): PBRT v4"
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  dnf -y install libXi-devel
  versionInfo="v4"
  installType="pbrt-$versionInfo"
  installPathV4="$installPath/$versionInfo"
  git clone --recursive https://github.com/mmp/$installType.git &> $installType-git.log
  mkdir -p $installPathV4
  cmake -B $installPathV4 -S $binDirectory/$installType &> $installType-cmake.log
  make -C $installPathV4 &> $installType-make.log
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
  versionInfo="19.5.569"
  versionEULA="2021-10-13"
  installType="houdini"
  installFile="$installType-$versionInfo-linux_x86_64_gcc9.3.tar.gz"
  downloadUrl="$binStorageHost/Houdini/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  [[ $renderEngines == *Maya* ]] && mayaPlugIn=--install-engine-maya || mayaPlugIn=--no-install-engine-maya
  [[ $renderEngines == *Unreal* ]] && unrealPlugIn=--install-engine-unreal || unrealPlugIn=--no-install-engine-unreal
  ./houdini*/houdini.install --auto-install --make-dir --accept-EULA $versionEULA $mayaPlugIn $unrealPlugIn &> $installType.log
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
  versionInfo="3.5.1"
  versionType="linux-x64"
  installPath="/usr/local/blender"
  installFile="blender-$versionInfo-$versionType.tar.xz"
  downloadUrl="$binStorageHost/Blender/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xf $installFile --xz
  mkdir -p $installPath
  mv blender-$versionInfo-$versionType/* $installPath
  binPaths="$binPaths:$installPath"
  echo "Customize (End): Blender"
fi

if [[ $renderEngines == *Unreal* ]] || [[ $renderEngines == *Unreal+PixelStream* ]]; then
  echo "Customize (Start): Unreal Engine Setup"
  dnf -y install libicu
  versionInfo="5.1.1"
  installType="unreal-engine"
  installPath="/usr/local/unreal"
  installFile="UnrealEngine-$versionInfo-release.tar.gz"
  downloadUrl="$binStorageHost/Unreal/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  mkdir -p $installPath
  mv UnrealEngine-$versionInfo-release/* $installPath
  $installPath/Setup.sh &> $installType-setup.log
  echo "Customize (End): Unreal Engine Setup"

  echo "Customize (Start): Unreal Project Files Generate"
  $installPath/GenerateProjectFiles.sh &> unreal-project-files-generate.log
  echo "Customize (End): Unreal Project Files Generate"

  echo "Customize (Start): Unreal Engine Build"
  make -C $installPath &> $installType-build.log
  echo "Customize (End): Unreal Engine Build"

  if [[ $renderEngines == *Unreal+PixelStream* ]]; then
    echo "Customize (Start): Unreal Pixel Streaming"
    installType="unreal-stream"
    git clone --recursive https://github.com/EpicGames/PixelStreamingInfrastructure --branch UE5.1 &> $installType-git.log
    dnf -y install coturn
    installFile="PixelStreamingInfrastructure/SignallingWebServer/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile &> $installType-signalling.log
    installFile="PixelStreamingInfrastructure/Matchmaker/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile &> $installType-matchmaker.log
    installFile="PixelStreamingInfrastructure/SFU/platform_scripts/bash/setup.sh"
    chmod +x $installFile
    ./$installFile &> $installType-sfu.log
    echo "Customize (End): Unreal Pixel Streaming"
  fi

  binPaths="$binPaths:$installPath"
fi

if [ $machineType == "Workstation" ]; then
  echo "Customize (Start): Teradici PCoIP"
  versionInfo="23.04.1"
  [[ $gpuPlatform == *GRID* ]] && installType=pcoip-agent-graphics || installType=pcoip-agent-standard
  installFile="pcoip-agent-offline-rocky8.6_$versionInfo-1.el8.x86_64.tar.gz"
  downloadUrl="$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  curl -o $installFile -L $downloadUrl
  mkdir -p $installType
  tar -xzf $installFile -C $installType
  cd $installType
  ./install-pcoip-agent.sh $installType usb-vhci &> ../$installType.log
  cd $binDirectory
  echo "Customize (End): Teradici PCoIP"
fi

echo "PATH=$PATH$binPaths" >> $aaaProfile
