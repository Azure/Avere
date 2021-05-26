#!/bin/bash

# report all lines, and exit on error
set -x

AZURE_HOME_DIR=/home/$ADMIN_USER_NAME

function retrycmd_if_failure() {
    set +e
    retries=$1; wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            set -e
            return 1
        else
            sleep $wait_sleep
        fi
    done
    set -e
    echo Executed \"$@\" $i times;
}

function update_linux() {
    retrycmd_if_failure 12 5 apt update
    retrycmd_if_failure 12 5 apt install -y unzip nfs-kernel-server iotop iperf3 bwm-ng
    retrycmd_if_failure 12 5 apt install -y unison
}

function configure_sync() {
    # installing per https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-data-ingest#use-the-msrsync-utility
    curl --retry 5 --retry-delay 5 -o /usr/bin/prime.py https://raw.githubusercontent.com/Azure/Avere/main/src/clientapps/dataingestor/prime.py
    sed -i 's:^#!/usr/bin/env python$:#!/usr/bin/env python2:' /usr/bin/prime.py
    chmod +x /usr/bin/prime.py

    curl --retry 5 --retry-delay 5 -o /usr/bin/msrsync https://raw.githubusercontent.com/jbd/msrsync/master/msrsync
    chmod +x /usr/bin/msrsync   

    # unison - popular two-way synchronization - https://github.com/bcpierce00/unison
    #retrycmd_if_failure 12 5 yum -y install epel-release
    #retrycmd_if_failure 12 5 yum -y install unison

    # here are some other choices that have not been installed
    #  syncthing - modern, actively developed, open, 2-way synchronization tool, syncthing does not preserve uid/gid
    #  https://dirsyncpro.org/index.html - for syncing two directories

    # download syncthing: https://computingforgeeks.com/install-and-configure-syncthing-on-centos-linux/
    # syncthing does not preserve uid/gid
    #mkdir -p /opt
    #cd /opt
    #curl -s https://api.github.com/repos/syncthing/syncthing/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -
    #tar xvf syncthing-linux-amd64*.tar.gz
    #cp syncthing-linux-amd64-*/syncthing  /bin/.
    #chmod +x /bin/syncthing
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "configure sync"
    configure_sync

    echo "installation complete"
    touch /opt/install.completed
}

main