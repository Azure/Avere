#!/bin/bash -ex

binPaths=""
binDirectory="/usr/local/bin"
cd $binDirectory

storageContainerUrl="https://azrender.blob.core.windows.net/bin"
storageContainerSas="?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D"

echo "Customize (Start): Image Build Platform"
dnf -y install epel-release
dnf -y install gcc gcc-c++
dnf -y install python-pip
dnf -y install nfs-utils
dnf -y install cmake
dnf -y install unzip
dnf -y install git
dnf -y install jq
echo "Customize (End): Image Build Platform"

echo "Customize (Start): Image Build Parameters"
buildConfig=$(echo $buildConfigEncoded | base64 -d)
machineType=$(echo $buildConfig | jq -r .machineType)
gpuPlatform=$(echo $buildConfig | jq -c .gpuPlatform)
renderManager=$(echo $buildConfig | jq -r .renderManager)
renderEngines=$(echo $buildConfig | jq -c .renderEngines)
adminUsername=$(echo $buildConfig | jq -r .adminUsername)
adminPassword=$(echo $buildConfig | jq -r .adminPassword)
echo "Machine Type: $machineType"
echo "GPU Platform: $gpuPlatform"
echo "Render Manager: $renderManager"
echo "Render Engines: $renderEngines"
echo "Customize (End): Image Build Parameters"

if [[ $gpuPlatform == *GRID* ]]; then
  echo "Customize (Start): NVIDIA GPU (GRID)"
  dnf -y install kernel-devel-$(uname -r)
  installFile="nvidia-gpu-grid.run"
  downloadUrl="https://go.microsoft.com/fwlink/?linkid=874272"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  ./$installFile -s 1> nvidia-grid.output.txt 2> nvidia-grid.error.txt
  echo "Customize (End): NVIDIA GPU (GRID)"
fi

if [[ $gpuPlatform == *CUDA* ]] || [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA GPU (CUDA)"
  dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
  dnf -y install cuda 1> nvidia-cuda.output.txt 2> nvidia-cuda.error.txt
  echo "Customize (End): NVIDIA GPU (CUDA)"
fi

if [[ $gpuPlatform == *CUDA.OptiX* ]]; then
  echo "Customize (Start): NVIDIA GPU (OptiX)"
  versionInfo="7.6.0"
  installFile="NVIDIA-OptiX-SDK-$versionInfo-linux64-x86_64-31894579.sh"
  downloadUrl="$storageContainerUrl/NVIDIA/OptiX/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  sdkDirectory="nvidia-optix"
  mkdir $sdkDirectory
  ./$installFile --skip-license --prefix="$binDirectory/$sdkDirectory" 1> nvidia-optix.output.txt 2> nvidia-optix.error.txt
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  buildDirectory="$binDirectory/$sdkDirectory/build"
  mkdir $buildDirectory
  cmake -B $buildDirectory -S $binDirectory/$sdkDirectory/SDK 1> nvidia-optix-cmake.output.txt 2> nvidia-optix-cmake.error.txt
  make -j -C $buildDirectory 1> nvidia-optix-make.output.txt 2> nvidia-optix-make.error.txt
  binPaths="$binPaths:$buildDirectory/bin"
  echo "Customize (End): NVIDIA GPU (OptiX)"
fi

if [ $machineType == "Scheduler" ]; then
  echo "Customize (Start): Azure CLI"
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  dnf -y install https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
  dnf -y install azure-cli
  echo "Customize (End): Azure CLI"

  echo "Customize (Start): NFS Server"
  systemctl --now enable nfs-server
  echo "Customize (End): NFS Server"

  echo "Customize (Start): CycleCloud"
  cycleCloudPath="usr/local/cyclecloud"
  cycleCloudRepoPath="/etc/yum.repos.d/cyclecloud.repo"
  echo "[cyclecloud]" > $cycleCloudRepoPath
  echo "name=CycleCloud" >> $cycleCloudRepoPath
  echo "baseurl=https://packages.microsoft.com/yumrepos/cyclecloud" >> $cycleCloudRepoPath
  echo "gpgcheck=1" >> $cycleCloudRepoPath
  echo "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> $cycleCloudRepoPath
  dnf -y install java-1.8.0-openjdk
  JAVA_HOME=/bin/java
  dnf -y install cyclecloud8
  binPaths="$binPaths:$cycleCloudPath/bin"
  cd /opt/cycle_server
  pip install ./tools/cyclecloud_api*.whl
  unzip -q ./tools/cyclecloud-cli.zip
  ./cyclecloud-cli-installer/install.sh --installdir $cycleCloudPath
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

if [ $renderManager == "Deadline" ]; then
  schedulerVersion="10.1.23.6"
  schedulerPath="/opt/Thinkbox/Deadline10/bin"
  schedulerDatabaseHost="$(hostname)"
  schedulerDatabasePort="27017"
  schedulerRepositoryPath="/DeadlineRepository"
  schedulerCertificateName="Deadline"
  schedulerCertificateFile="$schedulerCertificateName.pfx"
  schedulerRepositoryLocalMount="/mnt/scheduler"
  schedulerRepositoryCertificate="$schedulerRepositoryLocalMount/$schedulerCertificateFile"
  binPaths="$binPaths:$schedulerPath"
fi

rendererPathBlender="/usr/local/blender3"
rendererPathPBRT3="/usr/local/pbrt/v3"
rendererPathPBRT4="/usr/local/pbrt/v4"
rendererPathUnreal="/usr/local/unreal5"
rendererPathUnrealStream="$rendererPathUnreal/stream"

if [[ $renderEngines == *Blender* ]]; then
  binPaths="$binPaths:$rendererPathBlender"
fi
if [[ $renderEngines == *Unreal* ]]; then
  binPaths="$binPaths:$rendererPathUnreal"
fi
echo "PATH=$PATH$binPaths" > /etc/profile.d/aaa.sh

if [ $renderManager == "Deadline" ]; then
  echo "Customize (Start): Deadline Download"
  installFile="Deadline-$schedulerVersion-linux-installers.tar"
  downloadUrl="$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile
  echo "Customize (End): Deadline Download"

  if [ $machineType == "Scheduler" ]; then
    echo "Customize (Start): OpenSSL Certificates"
    pip install pyOpenSSL
    installFile="SSLGeneration-master.zip"
    downloadUrl="$storageContainerUrl/Deadline/$installFile$storageContainerSas"
    curl -o $installFile -L $downloadUrl
    unzip -q $installFile
    cd "SSLGeneration-master"
    schedulerCertificateOrg="Azure"
    schedulerCertificateOrgUnit="HPCRender"
    python ssl_gen.py --cert-org $schedulerCertificateOrg --cert-ou $schedulerCertificateOrgUnit --ca
    python ssl_gen.py --cert-name $schedulerCertificateName --server
    python ssl_gen.py --cert-name $schedulerCertificateName --client
    python ssl_gen.py --cert-name $schedulerCertificateName --pfx
    cd "keys"
    schedulerCertificateKeyFile="$(pwd)/$schedulerCertificateName.pem"
    schedulerCertificateAuthorityFile="$(pwd)/ca.crt"
    cat $schedulerCertificateName.crt > $schedulerCertificateKeyFile
    cat $schedulerCertificateName.key >> $schedulerCertificateKeyFile
    mkdir -p $schedulerRepositoryPath
    cp $schedulerCertificateFile $schedulerRepositoryPath/$schedulerCertificateFile
    chmod +r $schedulerRepositoryPath/$schedulerCertificateFile
    cd $binDirectory
    echo "Customize (End): OpenSSL Certificates"

    echo "Customize (Start): Mongo DB"
    mongoDbRepoPath="/etc/yum.repos.d/mongodb.repo"
    echo "[mongodb-org-4.2]" > $mongoDbRepoPath
    echo "name=MongoDB" >> $mongoDbRepoPath
    echo "baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/4.2/x86_64/" >> $mongoDbRepoPath
    echo "gpgcheck=1" >> $mongoDbRepoPath
    echo "enabled=1" >> $mongoDbRepoPath
    echo "gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc" >> $mongoDbRepoPath
    dnf -y install mongodb-org
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    # sed -i "/bindIp: 0.0.0.0/a\  tls:" /etc/mongod.conf
    # sed -i "/tls:/a\    mode: requireTLS" /etc/mongod.conf
    # sed -i "/mode: requireTLS/a\    certificateKeyFile: $schedulerCertificateKeyFile" /etc/mongod.conf
    # sed -i "/certificateKeyFile:/a\    CAFile: $schedulerCertificateAuthorityFile" /etc/mongod.conf
    # sed -i 's/#security:/security:/' /etc/mongod.conf
    # sed -i "/security:/a\  authorization: enabled" /etc/mongod.conf
    systemctl enable mongod
    systemctl start mongod
    echo "Customize (End): Mongo DB"

    echo "Customize (Start): Deadline Repository"
    installFile="DeadlineRepository-$schedulerVersion-linux-x64-installer.run"
    # ./$installFile --mode unattended --dbLicenseAcceptance accept --dbauth true --dbssl true --dbclientcert $schedulerRepositoryPath/$schedulerCertificateFile --dbhost $schedulerDatabaseHost --dbport $schedulerDatabasePort --prefix $schedulerRepositoryPath
    ./$installFile --mode unattended --dbLicenseAcceptance accept --dbhost $schedulerDatabaseHost --dbport $schedulerDatabasePort --prefix $schedulerRepositoryPath
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
  # $schedulerPath/deadlinecommand -ChangeRepositorySkipValidation Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate ""
  $schedulerPath/deadlinecommand -ChangeRepositorySkipValidation Direct $schedulerRepositoryLocalMount
  echo "Customize (End): Deadline Client"
fi

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
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git 1> pbrt-$versionInfo-git.output.txt 2> pbrt-$versionInfo-git.error.txt
  mkdir -p $rendererPathPBRT3
  cmake -B $rendererPathPBRT3 -S $binDirectory/pbrt-$versionInfo 1> pbrt-$versionInfo-cmake.output.txt 2> pbrt-$versionInfo-cmake.error.txt
  make -j -C $rendererPathPBRT3 1> pbrt-$versionInfo-make.output.txt 2> pbrt-$versionInfo-make.error.txt
  ln -s $rendererPathPBRT3/pbrt /usr/bin/pbrt3
  echo "Customize (End): PBRT v3"

  echo "Customize (Start): PBRT v4"
  dnf -y install mesa-libGL-devel
  dnf -y install libXrandr-devel
  dnf -y install libXinerama-devel
  dnf -y install libXcursor-devel
  dnf -y install libXi-devel
  versionInfo="v4"
  git clone --recursive https://github.com/mmp/pbrt-$versionInfo.git 1> pbrt-$versionInfo-git.output.txt 2> pbrt-$versionInfo-git.error.txt
  mkdir -p $rendererPathPBRT4
  cmake -B $rendererPathPBRT4 -S $binDirectory/pbrt-$versionInfo 1> pbrt-$versionInfo-cmake.output.txt 2> pbrt-$versionInfo-cmake.error.txt
  make -j -C $rendererPathPBRT4 1> pbrt-$versionInfo-make.output.txt 2> pbrt-$versionInfo-make.error.txt
  ln -s $rendererPathPBRT4/pbrt /usr/bin/pbrt4
  echo "Customize (End): PBRT v4"
fi

if [[ $renderEngines == *PBRT.Moana* ]]; then
  echo "Customize (Start): PBRT (Moana Island)"
  dataDirectory="moana"
  mkdir $dataDirectory
  installFile="island-basepackage-v1.1.tgz"
  downloadUrl="$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile -C $dataDirectory
  installFile="island-pbrt-v1.1.tgz"
  downloadUrl="$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile -C $dataDirectory
  installFile="island-pbrtV4-v2.0.tgz"
  downloadUrl="$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  tar -xzf $installFile -C $dataDirectory
  echo "Customize (End): PBRT (Moana Island)"
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
  echo "Customize (Start): Unreal"
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
    make -j -C $rendererPathUnreal
    echo "Customize (End): Unreal Project Files"
  fi
  echo "Customize (End): Unreal"
fi

if [[ $renderEngines == *Unreal.PixelStream* ]]; then
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
  dnf config-manager --set-enabled crb
  dnf -y groups install "KDE Plasma Workspaces" 1> kde.output.txt 2> kde.error.txt
  echo "Customize (End): Desktop Environment"

  echo "Customize (Start): Teradici PCoIP"
  versionInfo="22.09.2"
  installFile="pcoip-agent-offline-rhel8.6_$versionInfo-1.el8.x86_64.tar.gz"
  downloadUrl="$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  installDirectory="pcoip"
  mkdir $installDirectory
  tar -xzf $installFile -C $installDirectory
  cd $installDirectory
  ./install-pcoip-agent.sh pcoip-agent-graphics usb-vhci 1> pcoip.output.txt 2> pcoip.error.txt
  cd $installDirectory
  echo "Customize (End): Teradici PCoIP"

  echo "Customize (Start): V-Ray Benchmark"
  versionInfo="5.02.00"
  installFile="vray-benchmark-$versionInfo"
  downloadUrl="$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  curl -o $installFile -L $downloadUrl
  chmod +x $installFile
  echo "Customize (End): V-Ray Benchmark"
fi