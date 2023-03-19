function AddFileSystemMounts {
  local IFS="$1"
  read -a fsMounts <<< "$2"
  for fsMount in "${fsMounts[@]}"; do
    fsMountPoint=$(cut -d " " -f 2 <<< "$fsMount")
    if [ $(grep -c $fsMountPoint /etc/fstab) ]; then
      mkdir -p $fsMountPoint
      echo "$fsMount" >> /etc/fstab
    fi
  done
}
