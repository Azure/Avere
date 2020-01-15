#!/bin/bash -x

# variables that must be set beforehand
# EXPORT_PATH=/data
# EXPORT_OPTIONS="*(rw,sync,no_root_squash)"
#
# called like this:
#  sudo EXPORT_PATH=/data EXPORT_OPTIONS="*(rw,sync,no_root_squash)" ./installnfs.sh
#

set -x

# export the ephemeral disk
EPHEMERAL_DISK_PATH="/mnt"

function apt_get_update() {
    retries=10
    apt_update_output=/tmp/apt-get-update.out
    for i in $(seq 1 $retries); do
        timeout 120 apt-get update 2>&1 | tee $apt_update_output | grep -E "^([WE]:.*)|([eE]rr.*)$"
        [ $? -ne 0  ] && cat $apt_update_output && break || \
        cat $apt_update_output
        if [ $i -eq $retries ]; then
            return 1
        else sleep 30
        fi
    done
    echo Executed apt-get update $i times
}

function apt_get_install() {
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        # timeout occasionally freezes
        #echo "timeout $timeout apt-get install --no-install-recommends -y ${@}"
        #timeout $timeout apt-get install --no-install-recommends -y ${@}
        apt-get install --no-install-recommends -y ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo "failed"
            return 1
        else
            sleep $wait_sleep
            apt_get_update
        fi
    done
    echo "completed"
    echo Executed apt-get install --no-install-recommends -y \"$@\" $i times;
}

function config_linux() {
	export DEBIAN_FRONTEND=noninteractive  
	apt_get_update
	apt_get_install 20 10 180 nfs-kernel-server nfs-common
}

# export the ephemeral disk as specified by $EXPORT_PATH
function configure_nfs() {
    # stop the nfs service
    systemctl stop nfs-kernel-server.service

    # move the ephemeral mount to the mount chosen by the customer
    # we cannot do the symbolic link because it is not supported by nfsv4
    umount $EPHEMERAL_DISK_PATH
    mkdir -p $EXPORT_PATH
    sed -i "s:${EPHEMERAL_DISK_PATH}:${EXPORT_PATH}:g" /etc/fstab
    mount ${EXPORT_PATH}
    
    # configure NFS export for the export path
    grep "^${EXPORT_PATH}" /etc/exports > /dev/null 2>&1
    if [ $? = "0" ]; then
        echo "${EXPORT_PATH} is already exported. Returning..."
    else
        echo -e "\n${EXPORT_PATH}   ${EXPORT_OPTIONS}" >> /etc/exports
    fi

    # update to use 64 threads to get most performance
    sed -i 's/^RPCNFSDCOUNT=.*$/RPCNFSDCOUNT=64/g' /etc/default/nfs-kernel-server
    
    # start the nfs service
    systemctl start nfs-kernel-server.service
}

function main() {

    if [ -z "$EXPORT_PATH" ]; then
        echo "env var EXPORT_PATH is not defined, please define"
        exit 1
    fi

    if [ -z "$EXPORT_OPTIONS" ]; then
        echo "env var EXPORT_OPTIONS is not defined, please define"
        exit 1
    fi

    echo "config Linux"
    config_linux

    echo "setup NFS Server"
    configure_nfs
    
    echo "installation complete"
}

main
