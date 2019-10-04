#!/bin/bash

#
# This script configures the VMSS Host, and does the following:
#   1. sets the hostname to HOST_NAME_PREFIX + suffix of last two
#      octets of ip address
#   2. installs NFS and mounts the nas filer
# 
# Requires the following environment variables to be set:
#   HOST_NAME_PREFIX - is the prefix for the 
#   NFS_HOST - this is the hostname or ip address of the NFS filer
#   NFS_EXPORT - this is the path exported 
#   LOCAL_MOUNTPOINT - this is the local mount point

set -x # Display executed commands

function GetHostAddress() {
       for i in {1..120}; do
              hostname --all-ip-addresses > /dev/null
              if [ $? -eq 0 ]
              then
                     break
              fi
              sleep 1
       done
       echo $(hostname --all-ip-addresses | cut -d' ' -f1)
}

function GetHostName() {
       hostAddress="$(GetHostAddress)"
       hostAddressOctet3="$(cut --delimiter '.' --fields 3 <<< $hostAddress)"
       hostAddressOctet4="$(cut --delimiter '.' --fields 4 <<< $hostAddress)"
       echo "$HOST_NAME_PREFIX-$hostAddressOctet3-$hostAddressOctet4"
}

function SetHostName() {
       hostname $(GetHostName)
       /etc/init.d/network restart
}

function InstallNFS() {
    yum -y install nfs-utils
}

function MountNFS() {
    mkdir -p $LOCAL_MOUNTPOINT
    r=5
    for i in $(seq 1 $r); do
        mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' ${NFS_HOST}:${NFS_EXPORT} $LOCAL_MOUNTPOINT && break
        [ $i == $r ] && break 0
        sleep 5
    done
}

function main() {
    SetHostName

    #InstallNFS

    #MountNFS
}

main
