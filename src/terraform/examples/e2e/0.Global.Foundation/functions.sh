curl http://data.artist.studio:14000/dist/v1/install | sh

function SetServiceAccount {
  accountName=$1
  accountPassword=$2
  if ! id -u $accountName &> /dev/null; then
    useradd --system --password $accountPassword $accountName
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
  serviceAccountName=$2
  serviceAccountPassword=$3
  if [[ $renderManager == *RoyalRender* ]]; then
    installType="royal-render-client"
    rrWorkstation_installer -plugins -service -rrUser $serviceAccountName -rrUserPW $serviceAccountPassword -fwOut 2>&1 | tee $installType-service.log
    sed -i "s|BLENDER_PATH|local/blender|" /RoyalRender/render_apps/_install_paths/Blender.cfg
  fi
}
