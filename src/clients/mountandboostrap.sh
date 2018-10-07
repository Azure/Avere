#!/bin/bash

# Save this script to any Avere vFXT volume, for example:
#     /bootstrap/bootstrap.sh
#
# The following environment variables must be set:
#  BASE_DIR=/nfs
#  BOOTSTRAP_NFS_IP=10.0.0.22
#  BOOTSTRAP_SCRIPT_PATH=/bootstrap/bootstrap.sh
#  NFS_IP_CSV="10.0.0.22,10.0.0.23,10.0.0.24"
#  NFS_PATH=/msazure
#

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

function main() {
    retrycmd_if_failure 60 5 apt-get update
    retrycmd_if_failure 60 5 apt-get install -y nfs-common

    BOOTSTRAP_BASE_DIR=$BASE_DIR/b
    mkdir -p $BOOTSTRAP_BASE_DIR
    retrycmd_if_failure 60 5 mount -o "hard,nointr,proto=tcp,mountproto=tcp,retry=30" ${BOOTSTRAP_NFS_IP}:${NFS_PATH} ${BOOTSTRAP_BASE_DIR}
    NFS_IP_CSV="$NFS_IP_CSV" NFS_PATH="$NFS_PATH" BASE_DIR="$BASE_DIR" /bin/bash ${BOOTSTRAP_BASE_DIR}${BOOTSTRAP_SCRIPT_PATH} 2>&1 | tee -a /var/log/bootstrap.log
    umount $BOOTSTRAP_BASE_DIR
    rmdir $BOOTSTRAP_BASE_DIR
}

main