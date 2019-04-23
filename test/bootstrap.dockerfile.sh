#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

set -x

NODE_MOUNT_PREFIX="/node"

function retrycmd_if_failure() {
    retries=$1; max_wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            return 1
        else
            sleep $(($RANDOM % $max_wait_sleep))
        fi
    done
    echo Executed \"$@\" $i times;
}

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
        apt-get install --no-install-recommends -y ${@}
        echo "completed"
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            return 1
        else
            sleep $wait_sleep
            apt_get_update
        fi
    done
    echo Executed apt-get install --no-install-recommends -y \"$@\" $i times;
}

function config_linux() {
    export DEBIAN_FRONTEND=noninteractive
    apt_get_update
    apt_get_install 20 10 180 default-jre zip csh unzip
}

function mount_avere() {
    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        echo "Mounting to ${VFXT}:${NFS_PATH} to ${MOUNT_POINT}"
        mkdir -p $MOUNT_POINT
        # no need to write again if it is already there
        if grep -F --quiet "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}" /etc/fstab; then
            echo "not updating file, already there"
        else
            echo "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
            mount ${MOUNT_POINT}
        fi
        COUNTER=$(($COUNTER + 1))
    done
}


function write_copy_idrsa() {
    FILENAME=/home/$LINUX_USER/copy_idrsa.sh
    echo "#!/usr/bin/env bash" > "copy_idrsa.sh"
    COUNTER=0
    while [ $COUNTER -lt $NODE_COUNT ]; do
        echo "scp -o \"StrictHostKeyChecking no\" /home/$LINUX_USER/.ssh/id_rsa ${NODE_PREFIX}-${COUNTER}:.ssh/id_rsa" >> $FILENAME
        COUNTER=$[$COUNTER+1]
    done
    chown $LINUX_USER:$LINUX_USER $FILENAME
    chmod +x $FILENAME
}

function write_azure_clients() {
    FILENAME=/home/$LINUX_USER/azure-clients.conf
/bin/cat <<EOM >$FILENAME
hd=default,user=${LINUX_USER},shell=ssh
EOM
    # add each of the clients
    COUNTER=0
    while [ $COUNTER -lt $NODE_COUNT ]; do
        HOST_NUMBER=$(($COUNTER + 1))
        HOST_NUMBER_HEX=$( printf '%x' $HOST_NUMBER )
        NODE_NAME="${NODE_PREFIX}-${COUNTER}"
        IP=$( host ${NODE_NAME} | sed -e "s/.*\ //" )
        echo "NODE NAME ${NODE_NAME}, $IP"
        echo "hd=host${HOST_NUMBER_HEX},system=${IP}">>$FILENAME
        COUNTER=$[$COUNTER+1]
    done
    chown $LINUX_USER:$LINUX_USER $FILENAME
}



function write_docker_files() {
    write_copy_idrsa
    write_azure_clients

}

function main() {
    echo "config Linux"
    config_linux

    echo "mount avere"
    mount_avere

    echo "write docker files"
    write_docker_files

    echo "installation complete"
}

main