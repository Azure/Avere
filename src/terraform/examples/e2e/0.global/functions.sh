curl http://data.content.studio:14000/dist/v1/install | sh

function SetMount {
  storageMount="$1"
  storageCacheMount="$2"
  enableStorageCache=$3
  if [ $enableStorageCache == true ]; then
    AddMount "$storageCacheMount"
  else
    AddMount "$storageMount"
  fi
}

function AddMount {
  fileSystemMount="$1"
  mountDirectory=$(cut -d " " -f 2 <<< "$fileSystemMount")
  if [ $(grep -c $mountDirectory /etc/fstab) ]; then
    mkdir -p $mountDirectory
    echo "$fileSystemMount" >> /etc/fstab
  fi
}

function EnableRenderClient {
  renderManager="$1"
  servicePassword="$2"
  # if [[ $renderManager == *RoyalRender* ]]; then
  #   installType="royal-render-client"

  #   installPath="RoyalRender*"
  #   installFile="rrSetup_linux"
  #   rrRootShare="\\scheduler.content.studio\RoyalRender"
  #   ./$installPath/$installFile -console -rrRoot $rrRootShare &> $installType.log

  #   serviceUser="rrService"
  #   useradd -r $serviceUser -p "$servicePassword"
  #   rrWorkstation_installer -plugins -service -rrUser $serviceUser -rrUserPW "$servicePassword" -fwOut &> $installType-service.log
  # fi
}
