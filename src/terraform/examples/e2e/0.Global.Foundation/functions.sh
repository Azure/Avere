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

function EnableClientApp {
  renderManager="$1"
  curl http://data.artist.studio:14000/dist/v1/install | sh
}
