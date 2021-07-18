#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
set -x

# NEED following ENV VARS
# BOOTSTRAP_PATH - the mount path for bootstrap
#
# STORAGE_ACCOUNT_RESOURCE_GROUP - the resource group of the storage account
# STORAGE_ACCOUNT - the storage account hosting the job queue

# QUEUE_PREFIX - the queue prefix
# BOOTSTRAP_EXPORT_PATH
# BOOTSTRAP_MOUNT_ADDRESS
# BOOTSTRAP_SCRIPT
# VMSS_USERNAME
# (OPT)VMSS_SUBNET
# (OPT)VMSS_SSHPUBLICKEY
# (OPT)VMSS_PASSWORD
# (OPT)VMSS_WORKER_COUNT

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

    # copy the systemd file and search replace users/groups/workdircsv
    SRC_FILE=$BOOTSTRAP_BASE_PATH/systemd/${CACHEWARMER_MANAGER_SERVICE_FILE}
    DST_FILE=/lib/systemd/system/${CACHEWARMER_MANAGER_SERVICE_FILE}

    cp $SRC_FILE $DST_FILE
    sed -i "s/USERREPLACE/$SERVICE_USER/g" $DST_FILE
    sed -i "s/GROUPREPLACE/$SERVICE_USER/g" $DST_FILE
    sed -i "s:STORAGE_RG_REPLACE:$STORAGE_ACCOUNT_RESOURCE_GROUP:g" $DST_FILE
    sed -i "s:STORAGE_ACCOUNT_REPLACE:$STORAGE_ACCOUNT:g" $DST_FILE
    sed -i "s/QUEUE_PREFIX_REPLACE/$QUEUE_PREFIX/g" $DST_FILE
    sed -i "s:BOOTSTRAP_EXPORT_PATH_REPLACE:$BOOTSTRAP_EXPORT_PATH:g" $DST_FILE
    sed -i "s:BOOTSTRAP_MOUNT_ADDRESS_REPLACE:$BOOTSTRAP_MOUNT_ADDRESS:g" $DST_FILE
    sed -i "s:BOOTSTRAP_SCRIPT_PATH_REPLACE:$BOOTSTRAP_SCRIPT:g" $DST_FILE
    sed -i "s:VMSS_USERNAME_REPLACE:$VMSS_USERNAME:g" $DST_FILE
    
    if [[ -z "${VMSS_SSHPUBLICKEY}" ]]; then
        sed -i "s:VMSS_SSH_PUBLIC_KEY_REPLACE::g" $DST_FILE
    else
        sed -i "s:VMSS_SSH_PUBLIC_KEY_REPLACE:-vmssSshPublicKey '$VMSS_SSHPUBLICKEY':g" $DST_FILE
    fi
    # disable output so secrets are not printed
    set +x
    if [[ -z "${VMSS_PASSWORD}" ]]; then
        sed -i "s:VMSS_PASSWORD_REPLACE::g" $DST_FILE
    else
        sed -i "s:VMSS_PASSWORD_REPLACE:-vmssPassword '$VMSS_PASSWORD':g" $DST_FILE
    fi
    set -x
    if [[ -z "${VMSS_SUBNET}" ]]; then
        sed -i "s/VMSS_SUBNET_NAME_REPLACE//g" $DST_FILE
    else
        sed -i "s/VMSS_SUBNET_NAME_REPLACE/-vmssSubnetName $VMSS_SUBNET/g" $DST_FILE
    fi
    
    if [[ -z "${VMSS_WORKER_COUNT}" ]]; then
        sed -i "s/VMSS_WORKER_COUNT_REPLACE//g" $DST_FILE
    else
        sed -i "s/VMSS_WORKER_COUNT_REPLACE/-workerCount $VMSS_WORKER_COUNT/g" $DST_FILE
    fi

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
    
    # ensure the logs are rotating
    if grep -F --quiet "/var/log/cachewarmer-manager.log" /etc/logrotate.d/rsyslog; then
        echo "not updating /etc/logrotate.d/rsyslog, already there"
    else
        /bin/cat <<EOM >>/etc/logrotate.d/rsyslog
/var/log/cachewarmer-manager.log
{
        rotate 2
        daily
        missingok
        notifempty
        compress
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
EOM
    fi
    
    # restart syslog
    systemctl restart rsyslog
}

function stop_service() {
    systemctl stop ${CACHEWARMER_MANAGER_SERVICE}
    systemctl disable ${CACHEWARMER_MANAGER_SERVICE_FILE}
}

function configure_service() {
    systemctl daemon-reload
    systemctl enable ${CACHEWARMER_MANAGER_SERVICE_FILE}
    systemctl start ${CACHEWARMER_MANAGER_SERVICE}
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