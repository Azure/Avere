function StartProcess {
  command="$1"
  logFile=$2
  $command 1>> $logFile.out 2>> $logFile.err
  cat $logFile.err
}

function FileExists {
  filePath=$1
  [ -f $filePath ]
}

function GetEncodedValue {
  echo $1 | base64 -d | jq -r $2
}

function SetFileSystems {
  fileSystems="$1"
  curl -L https://github.com/Azure/AZNFS-mount/releases/download/1.0.10/aznfs_install.sh | bash
  for fileSystem in $(echo $fileSystems | jq -r '.[] | @base64'); do
    if [ $(GetEncodedValue $fileSystem .enable) == true ]; then
      SetFileSystemMounts "$(GetEncodedValue $fileSystem .mounts)"
    fi
  done
  systemctl daemon-reload
  mount -a
}

function SetFileSystemMounts {
  fileSystemMounts="$1"
  for fileSystemMount in $(echo $fileSystemMounts | jq -r '.[] | @base64'); do
    mount=$(echo $fileSystemMount | base64 -d)
    mountDirectory=$(cut -d " " -f 2 <<< "$mount")
    if [ $(grep -c $mountDirectory /etc/fstab) ]; then
      mkdir -p $mountDirectory
      echo "$mount" >> /etc/fstab
    fi
  done
}

function EnableFarmClient {
  curl http://content.artist.studio:14000/dist/v1/install | sh
}
