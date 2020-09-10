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
RSYSLOG_FILE="36-cachewarmer-worker.conf"
CACHEWARMER_WORKER_SERVICE=cachewarmer-worker
CACHEWARMER_WORKER_SERVICE_FILE="${CACHEWARMER_WORKER_SERVICE}.service"

function copy_binaries() {
    BOOTSTRAP_BASE_PATH="$(dirname ${BOOTSTRAP_PATH}${BOOTSTRAP_SCRIPT})"
    CACHEWARMER_BIN=$BOOTSTRAP_BASE_PATH/cachewarmerbin
    cp $CACHEWARMER_BIN/* /usr/local/bin/.
}

function write_system_files() {
    # configuration inspired by https://fabianlee.org/2017/05/21/golang-running-a-go-binary-as-a-systemd-service-on-ubuntu-16-04/
    BOOTSTRAP_BASE_PATH="$(dirname ${BOOTSTRAP_PATH}${BOOTSTRAP_SCRIPT})"

    # copy the systemd file and search replace users/groups/workdircsv
    SRC_FILE=$BOOTSTRAP_BASE_PATH/systemd/${CACHEWARMER_WORKER_SERVICE_FILE}
    DST_FILE=/lib/systemd/system/${CACHEWARMER_WORKER_SERVICE_FILE}

    cp $SRC_FILE $DST_FILE
    sed -i "s/USERREPLACE/$SERVICE_USER/g" $DST_FILE
    sed -i "s/GROUPREPLACE/$SERVICE_USER/g" $DST_FILE
    sed -i "s/JOBMOUNTADDRESSREPLACE/$JOB_MOUNT_ADDRESS/g" $DST_FILE
    sed -i "s:JOBEXPORTREPLACE:$JOB_EXPORT_PATH:g" $DST_FILE
    sed -i "s:JOBBASEREPLACE:$JOB_BASE_PATH:g" $DST_FILE

    if [ -f '/etc/centos-release' ]; then 
        sed -i "s/chown syslog:adm/chown root:root/g" $DST_FILE
    fi

    # copy the rsyslog file
    cp $BOOTSTRAP_BASE_PATH/rsyslog/$RSYSLOG_FILE /etc/rsyslog.d/.
}

function configure_rsyslog() {
    # enable listen on port 514/TCP
    sed -i 's/^#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf
    systemctl restart rsyslog
}

function stop_service() {
    systemctl stop ${CACHEWARMER_WORKER_SERVICE_FILE}
    systemctl disable ${CACHEWARMER_WORKER_SERVICE_FILE}
}

function configure_service() {
    systemctl daemon-reload
    systemctl enable ${CACHEWARMER_WORKER_SERVICE_FILE}
    systemctl start ${CACHEWARMER_WORKER_SERVICE}
}

function main() {
    echo "stop service if exists"
    stop_service

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