#!/bin/bash 

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
STATS_DIR="/stats"

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
        if grep -F --quiet "$VFXT" /etc/fstab; then
            echo "not updating file, already there"
        else
            echo "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
            mount ${MOUNT_POINT}
        fi
        COUNTER=$(($COUNTER + 1))
    done
}

function copy_edasim_binaries() {
    BOOTSTRAP_PATH="$(dirname ${BASE_DIR}${NODE_MOUNT_PREFIX}0${BOOTSTRAP_SCRIPT_PATH})"
    EDASIM_BIN=$BOOTSTRAP_PATH/edasim
    cp $EDASIM_BIN/* /usr/local/bin/.
}

function get_node_csv_string() {
    WORKING_DIR=$1; shift
    COUNTER=0
    RETURN_STR=""
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        if [ "$COUNTER" -ne "0" ]; then
            RETURN_STR="${RETURN_STR},"
        fi
        TARGET_DIR=${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}${WORKING_DIR}
        mkdir -p ${TARGET_DIR}
        chown $LINUX_USER:$LINUX_USER ${TARGET_DIR}
        RETURN_STR="${RETURN_STR}${TARGET_DIR}"
        COUNTER=$(($COUNTER + 1))
    done
    echo $RETURN_STR
}

function configure_user() {
    USER_PROFILE_FILE="${AZURE_HOME_DIR}/.profile"
    echo "export AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT" >> $USER_PROFILE_FILE
    echo "export AZURE_STORAGE_ACCOUNT_KEY=\"$AZURE_STORAGE_ACCOUNT_KEY\"" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_SENDERKEYNAME=$AZURE_EVENTHUB_SENDERKEYNAME" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_SENDERKEY=\"$AZURE_EVENTHUB_SENDERKEY\"" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_NAMESPACENAME=$AZURE_EVENTHUB_NAMESPACENAME" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_HUBNAME=$AZURE_EVENTHUB_HUBNAME" >> $USER_PROFILE_FILE

    BOOTSTRAP_PATH="$(dirname ${BASE_DIR}${NODE_MOUNT_PREFIX}0${BOOTSTRAP_SCRIPT_PATH})"

    # write the jobsubmitter script file
    JOBDIRCSV=$(get_node_csv_string $JOB_DIR)
    JOBSUBMITTERSCRIPT="${AZURE_HOME_DIR}/job_submitter.sh"
    /bin/cat <<EOM >$JOBSUBMITTERSCRIPT
jobsubmitter -userCount=16 -jobBaseFilePathCSV=${JOBDIRCSV} -jobCount 3000
EOM
    chown $LINUX_USER:$LINUX_USER $JOBSUBMITTERSCRIPT
    chmod 755 $JOBSUBMITTERSCRIPT

    # write the jobsubmitter script file
    STATS_COLLECTOR_SCRIPT="${AZURE_HOME_DIR}/stats_collector.sh"
    TARGET_DIR=${BASE_DIR}${NODE_MOUNT_PREFIX}0${STATS_DIR}
    mkdir -p ${TARGET_DIR}
    chown $LINUX_USER:$LINUX_USER ${TARGET_DIR}
    /bin/cat <<EOM >$STATS_COLLECTOR_SCRIPT
statscollector -statsFilePath=${TARGET_DIR}
EOM
    chown $LINUX_USER:$LINUX_USER $STATS_COLLECTOR_SCRIPT
    chmod 755 $STATS_COLLECTOR_SCRIPT
}

function main() {
    echo "config Linux"
    config_linux

    echo "mount avere"
    mount_avere

    echo "copy edasim binaries"
    copy_edasim_binaries

    echo "configure user to run the job submitter"
    configure_user

    echo "installation complete"
}

main