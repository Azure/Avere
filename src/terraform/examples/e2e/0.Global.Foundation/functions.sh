curl http://data.artist.studio:14000/dist/v1/install | sh

function SetServiceAccount {
  serviceAccount=$1
  servicePassword=$2
  if ! id -u $serviceAccount &> /dev/null; then
    useradd --system --password $servicePassword $serviceAccount
  fi
}

function GetEncodedValue {
  echo $1 | base64 -d | jq -r $2
}

function SetFileSystemMount {
  fileSystemMount="$1"
  mountDirectory=$(cut -d " " -f 2 <<< "$fileSystemMount")
  if [ $(grep -c $mountDirectory /etc/fstab) ]; then
    mkdir -p $mountDirectory
    echo "$fileSystemMount" >> /etc/fstab
  fi
}

function EnableSchedulerClient {
  renderManager="$1"
  serviceAccount=$2
  servicePassword=$3
  # if [[ $renderManager == *RoyalRender* ]]; then
  #   installType="royal-render-client"
  #   rrWorkstation_installer -plugins -service -rrUser $serviceAccount -rrUserPW $servicePassword -fwOut 2>&1 | tee $installType-service.log
  # fi
}