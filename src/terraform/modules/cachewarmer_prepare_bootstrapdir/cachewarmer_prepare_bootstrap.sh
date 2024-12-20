#!/bin/bash

# before running this script define the following env vars
# LOCAL_MOUNT_DIR=/b
# BOOTSTRAP_MOUNT_ADDRESS=FILE_ADDRESS
# BOOTSTRAP_MOUNT_EXPORT=/data
# BOOTSTRAP_SUBDIR=/bootstrap
#
# # leave CACHEWARMER_MANAGER_PATH empty if you did not build your own cachewarmer binaries
# CACHEWARMER_MANAGER_PATH=""
# CACHEWARMER_WORKER_PATH=""
# CACHEWARMER_JOBSUBMITTER_PATH=""

if [ -z $LOCAL_MOUNT_DIR ]; then
    echo "LOCAL_MOUNT_DIR is not set"
    return
fi
if [ -z $BOOTSTRAP_MOUNT_ADDRESS ]; then
    echo "BOOTSTRAP_MOUNT_ADDRESS is not set"
    return
fi
if [ -z $BOOTSTRAP_MOUNT_EXPORT ]; then
    echo "BOOTSTRAP_MOUNT_EXPORT is not set"
    return
fi
if [ -z $BOOTSTRAP_SUBDIR ]; then
    echo "BOOTSTRAP_SUBDIR is not set"
    return
fi

set -x

# go home
cd

# "sudo -E" required to pass environment variables including proxy settings

# remove a previous install if one exists
sudo -E rm -f $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/bootstrap.cachewarmer-manager.sh
sudo -E rm -f $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/bootstrap.cachewarmer-worker.sh
sudo -E rm -f $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/rsyslog/35-cachewarmer-manager.conf
sudo -E rm -f $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/rsyslog/36-cachewarmer-worker.conf
sudo -E rm -f $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/systemd/cachewarmer-manager.service
sudo -E rm -f $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/systemd/cachewarmer-worker.service

# create the bootstrap directory
sudo -E mkdir -p $LOCAL_MOUNT_DIR
sudo -E mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' $BOOTSTRAP_MOUNT_ADDRESS:$BOOTSTRAP_MOUNT_EXPORT $LOCAL_MOUNT_DIR
sudo -E mkdir -p $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/cachewarmerbin
sudo -E mkdir -p $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/rsyslog
sudo -E mkdir -p $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/systemd

# download the content
sudo -E curl --retry 5 --retry-delay 5 -L -o $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/bootstrap.cachewarmer-manager.sh https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh
sudo -E curl --retry 5 --retry-delay 5 -L -o $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/bootstrap.cachewarmer-worker.sh https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh
sudo -E curl --retry 5 --retry-delay 5 -L -o $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/rsyslog/35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf
sudo -E curl --retry 5 --retry-delay 5 -L -o $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/rsyslog/36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf
sudo -E curl --retry 5 --retry-delay 5 -L -o $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/systemd/cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service
sudo -E curl --retry 5 --retry-delay 5 -L -o $LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/systemd/cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service

TARGET_PATH=$LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/cachewarmerbin/cachewarmer-manager
if [ -z "$CACHEWARMER_MANAGER_PATH" ]; then
    browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "cachewarmer-manager$")
    sudo -E curl --retry 5 --retry-delay 5 -L -o $TARGET_PATH $browser_download_url
    sudo -E chmod +x $TARGET_PATH
else
    sudo -E cp $CACHEWARMER_MANAGER_PATH $TARGET_PATH
fi
TARGET_PATH=$LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/cachewarmerbin/cachewarmer-worker
if [ -z "$CACHEWARMER_WORKER_PATH" ]; then
    browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "cachewarmer-worker$")
    sudo -E curl --retry 5 --retry-delay 5 -L -o $TARGET_PATH $browser_download_url
    sudo -E chmod +x $TARGET_PATH
else
    sudo -E cp $CACHEWARMER_WORKER_PATH $TARGET_PATH
fi
TARGET_PATH=$LOCAL_MOUNT_DIR/$BOOTSTRAP_SUBDIR/cachewarmerbin/cachewarmer-jobsubmitter
if [ -z "$CACHEWARMER_JOBSUBMITTER_PATH" ]; then
    browser_download_url=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .assets[].browser_download_url | grep -e "cachewarmer-jobsubmitter$")
    sudo -E curl --retry 5 --retry-delay 5 -L -o $TARGET_PATH $browser_download_url
    sudo -E chmod +x $TARGET_PATH
else
    sudo -E cp $CACHEWARMER_JOBSUBMITTER_PATH $TARGET_PATH
fi

# umount and remove the local mount directory
sudo -E umount $LOCAL_MOUNT_DIR
sudo -E rmdir $LOCAL_MOUNT_DIR

set +x