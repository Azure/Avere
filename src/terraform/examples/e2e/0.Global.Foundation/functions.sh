function StartProcess {
  command="$1"
  logFile=$2
  $command 1>> $logFile.out 2>> $logFile.err
  cat $logFile.err
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

function EnableFarmClient {
  curl http://content.artist.studio:14000/dist/v1/install | sh
}
