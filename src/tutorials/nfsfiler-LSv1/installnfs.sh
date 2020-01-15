#!/bin/bash -x

# variables that must be set beforehand
# EXPORT_PATH=/data
# EXPORT_OPTIONS="*(rw,async,no_root_squash)"
#
# called like this:
#  sudo EXPORT_PATH=/data EXPORT_OPTIONS="*(rw,async,no_root_squash)" ./installnfs.sh
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
    # add a symbolic link to the ephemeral disk, then export
    ln -s $EPHEMERAL_DISK_PATH $EXPORT_PATH
    
    # configure NFS export for the export path
    grep "^${EXPORT_PATH}" /etc/exports > /dev/null 2>&1
    if [ $? = "0" ]; then
        echo "${EXPORT_PATH} is already exported. Returning..."
    else
        echo -e "\n${EXPORT_PATH}   ${EXPORT_OPTIONS}" >> /etc/exports
    fi
    
    systemctl enable nfs-kernel-server.service
    systemctl restart nfs-kernel-server.service
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
