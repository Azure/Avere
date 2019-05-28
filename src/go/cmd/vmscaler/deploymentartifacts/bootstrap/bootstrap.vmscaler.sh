#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
set -x

###########################################################
# on rare occasions the extension beats the user setup,
# wait until complete
###########################################################
WAIT_SECONDS=600
AZURE_HOME_DIR=/home/$LINUX_USER
function wait_azure_home_dir() {
    counter=0
    while [ ! -d $AZURE_HOME_DIR ]; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $WAIT_SECONDS ]; then
            echo "directory $AZURE_HOME_DIR not available after waiting $WAIT_SECONDS seconds"
            exit 1
        fi
    done
}
echo "wait azure home dir"
wait_azure_home_dir
###########################################################

NODE_MOUNT_PREFIX="/node"
JOB_DIR="/job"
WORK_DIR="/work"
RSYSLOG_FILE="34-vmscaler.conf"
VMSCALER_SERVICE=vmscaler
VMSCALER_SERVICE_FILE="${VMSCALER_SERVICE}.service"

function remove_quotes() {
        QUOTED_STR=$1; shift
        QUOTED_STR=$(sed -e 's/^"//' -e 's/"$//' <<<"$QUOTED_STR")
        QUOTED_STR=$(sed -e "s/^'//" -e "s/'\$//" <<<"$QUOTED_STR")
        echo $QUOTED_STR
}

function copy_binaries() {
    BOOTSTRAP_BASE_PATH="$(dirname ${BOOTSTRAP_PATH}${BOOTSTRAP_SCRIPT})"
    VMSCALER_BIN=$BOOTSTRAP_BASE_PATH/vmscalerbin
    cp $VMSCALER_BIN/* /usr/local/bin/.
}

function write_system_files() {
    # configuration inspired by https://fabianlee.org/2017/05/21/golang-running-a-go-binary-as-a-systemd-service-on-ubuntu-16-04/
    BOOTSTRAP_BASE_PATH="$(dirname ${BOOTSTRAP_PATH}${BOOTSTRAP_SCRIPT})"

    # write env file
    ENVFILE=/etc/default/vmscaler
    /bin/cat <<EOM >$ENVFILE
AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_ACCOUNT_KEY="$(remove_quotes $AZURE_STORAGE_ACCOUNT_KEY)"
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
EOM
    chmod 600 $ENVFILE

    # copy the systemd file and search replace users/groups/workdircsv
    SRC_FILE=$BOOTSTRAP_BASE_PATH/systemd/${VMSCALER_SERVICE_FILE}
    DST_FILE=/lib/systemd/system/${VMSCALER_SERVICE_FILE}

    cp $SRC_FILE $DST_FILE

    sed -i "s:IMAGEIDREPLACE:$IMAGE_ID:g" $DST_FILE
    sed -i "s/LOCATIONREPLACE/$LOCATION/g" $DST_FILE
    sed -i "s/VMSECRETREPLACE/$VM_PASSWORD/g" $DST_FILE
    sed -i "s/RESOURCEGROUPREPLACE/$RESOURCE_GROUP/g" $DST_FILE
    sed -i "s/VNETRGREPLACE/$VNET_RG/g" $DST_FILE
    sed -i "s/VNETNAMEREPLACE/$VNET_NAME/g" $DST_FILE
    sed -i "s/SUBNETREPLACE/$SUBNET_NAME/g" $DST_FILE
    sed -i "s/SKUREPLACE/$SKU/g" $DST_FILE
    sed -i "s/VMSPERVMSSREPLACE/$VMS_PER_VMSS/g" $DST_FILE
    sed -i "s/PRIORITYREPLACE/$PRIORITY/g" $DST_FILE
    sed -i "s/USERREPLACE/$LINUX_USER/g" $DST_FILE
    sed -i "s/GROUPREPLACE/$LINUX_USER/g" $DST_FILE

    # copy the rsyslog file
    cp $BOOTSTRAP_BASE_PATH/rsyslog/$RSYSLOG_FILE /etc/rsyslog.d/.

    # copy the delete vmss instance file
    SRC_FILE=$BOOTSTRAP_BASE_PATH/delete_vmss_instance.sh
    DST_FILE=/home/$LINUX_USER/delete_vmss_instance.sh
    cp  $SRC_FILE $DST_FILE
    sed -i "s/STORAGEACCOUNTREPLACE/$AZURE_STORAGE_ACCOUNT/g" $DST_FILE
    sed -i "s:STORAGEKEYREPLACE:$(remove_quotes $AZURE_STORAGE_ACCOUNT_KEY):g" $DST_FILE
}

function configure_rsyslog() {
    # enable listen on port 514/TCP
    sed -i 's/^#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf
    systemctl restart rsyslog
}

function configure_service() {
    systemctl enable ${VMSCALER_SERVICE_FILE}
    sudo systemctl start ${VMSCALER_SERVICE}
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