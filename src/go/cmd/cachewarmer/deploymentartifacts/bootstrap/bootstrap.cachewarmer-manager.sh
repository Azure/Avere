#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
set -x

# NEED following ENV VARS
# BOOTSTRAP_PATH
# BOOTSTRAP_SCRIPT
# JOB_MOUNT_ADDRESS - the nfs address of the filer hosting cache warmer jobs
# JOB_EXPORT_PATH - the nfs export path for the cache warmer jobs
# JOB_BASE_PATH - the job base path, usually '/'

SERVICE_USER=root
RSYSLOG_FILE="35-cachewarmer-manager.conf"
CACHEWARMER_MANAGER_SERVICE=cachewarmer-manager
CACHEWARMER_MANAGER_SERVICE_FILE="${CACHEWARMER_MANAGER_SERVICE}.service"

function copy_binaries() {
    BOOTSTRAP_BASE_PATH="$(dirname ${BOOTSTRAP_PATH}${BOOTSTRAP_SCRIPT})"
    CACHEWARMER_BIN=$BOOTSTRAP_BASE_PATH/cachewarmerbin
    cp $CACHEWARMER_BIN/* /usr/local/bin/.
}

function write_system_files() {
    # configuration inspired by https://fabianlee.org/2017/05/21/golang-running-a-go-binary-as-a-systemd-service-on-ubuntu-16-04/
    BOOTSTRAP_BASE_PATH="$(dirname ${BOOTSTRAP_PATH}${BOOTSTRAP_SCRIPT})"

    # disable output so secrets are not printed
    set +x
    set -x

    # copy the systemd file and search replace users/groups/workdircsv
    SRC_FILE=$BOOTSTRAP_BASE_PATH/systemd/${CACHEWARMER_MANAGER_SERVICE_FILE}
    DST_FILE=/lib/systemd/system/${CACHEWARMER_MANAGER_SERVICE_FILE}

    cp $SRC_FILE $DST_FILE
    sed -i "s/USERREPLACE/$SERVICE_USER/g" $DST_FILE
    sed -i "s/GROUPREPLACE/$SERVICE_USER/g" $DST_FILE
    sed -i "s:JOB_BASE_PATH_REPLACE:$JOB_BASE_PATH:g" $DST_FILE
    sed -i "s:JOB_EXPORT_PATH_REPLACE:$JOB_EXPORT_PATH:g" $DST_FILE
    sed -i "s/JOB_MOUNT_ADDRESS_REPLACE/$JOB_MOUNT_ADDRESS/g" $DST_FILE
    sed -i "s:BOOTSTRAP_EXPORT_PATH_REPLACE:$JOB_BASE_PATH:g" $DST_FILE
    sed -i "s:BOOTSTRAP_MOUNT_ADDRESS_REPLACE:$JOB_EXPORT_PATH:g" $DST_FILE
    sed -i "s/BOOTSTRAP_SCRIPT_PATH_REPLACE/$BOOTSTRAP_SCRIPT/g" $DST_FILE
    sed -i "s:VMSS_USERNAME_REPLACE:$JOB_BASE_PATH:g" $DST_FILE
    sed -i "s:VMSS_SSH_PUBLIC_KEY_REPLACE:$JOB_EXPORT_PATH:g" $DST_FILE
    sed -i "s/VMSS_SUBNET_NAME_REPLACE/$JOB_MOUNT_ADDRESS/g" $DST_FILE

    # copy the rsyslog file
    cp $BOOTSTRAP_BASE_PATH/rsyslog/$RSYSLOG_FILE /etc/rsyslog.d/.
}

function configure_rsyslog() {
    # enable listen on port 514/TCP
    sed -i 's/^#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf
    systemctl restart rsyslog
}

function configure_service() {
    systemctl enable ${CACHEWARMER_MANAGER_SERVICE_FILE}
    sudo systemctl start ${CACHEWARMER_MANAGER_SERVICE}
}

function main() {
    echo "copy binaries"
    copy_binaries

    echo "write system files"
    write_system_files

    echo "configure rsyslog"
    configure_rsyslog

    echo "start the service"
    configure_service

    echo "installation complete"
}

main