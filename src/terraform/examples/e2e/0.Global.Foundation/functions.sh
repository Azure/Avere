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
  for fileSystem in $(echo $fileSystems | jq -r '.[] | @base64'); do
    if [ $(GetEncodedValue $fileSystem .enable) == true ]; then
      SetFileSystemMounts "$(GetEncodedValue $fileSystem .mounts)"
    fi
  done
  mount -a
}

function SetFileSystemMounts {
  fileSystemMounts="$1"
  for fileSystemMount in $(echo $fileSystemMounts); do
    mountDirectory=$(cut -d " " -f 2 <<< "$fileSystemMount")
    if [ $(grep -c $mountDirectory /etc/fstab) ]; then
      mkdir -p $mountDirectory
      echo "$fileSystemMount" >> /etc/fstab
    fi
  done
}

function EnableFarmClient {
  curl http://content.artist.studio:14000/dist/v1/install | sh
}
