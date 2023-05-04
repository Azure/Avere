#curl http://data.content.studio:14000/dist/v1/install | sh

function SetMount {
  storageMount="$1"
  storageCacheMount="$2"
  enableStorageCache=$3
  if [ "$enableStorageCache" == "true" ]; then
    AddMount "$storageCacheMount"
  else
    AddMount "$storageMount"
  fi
}

function AddMount {
  fsMount="$1"
  fsMountPoint=$(cut -d " " -f 2 <<< "$fsMount")
  if [ $(grep -c $fsMountPoint /etc/fstab) ]; then
    mkdir -p $fsMountPoint
    echo "$fsMount" >> /etc/fstab
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
  #   ./$installPath/$installFile -console -rrRoot $rrRootShare 1> $installType.out.log 2> $installType.err.log

  #   serviceUser="rrService"
  #   useradd -r $serviceUser -p "$servicePassword"
  #   rrWorkstation_installer -plugins -service -rrUser $serviceUser -rrUserPW "$servicePassword" -fwOut 1> $installType-service.out.log 2> $installType-service.err.log
  # fi
}
