#!/bin/bash

#
# The following script mounts a default round robin's across the
# vFXT ip addresses.  
#
# Save this script to any Avere vFXT volume, for example:
#     /bootstrap/centosbootstrap.sh
#
# The following environment variables must be set:
#     NFS_IP_CSV="172.16.0.22,172.16.0.23,172.16.0.24"
#     NFS_PATH=/msazure
#     BASE_DIR=/avere
#     BOOTSTRAP_PATH=/b
#     BOOTSTRAP_SCRIPT=/b/bootstrap/centosbootstrap.sh
#     BOOTSTRAP_NFS_IP=172.16.0.22
#     BOOTSTRAP_NFS_PATH=msazure
#
# This is executed as a startup task from batch, using the 
# following command line:
#
#     bash -c 'sudo yum -y install nfs-utils && sudo mkdir -p $BOOTSTRAP_PATH && sudo mount ${BOOTSTRAP_NFS_IP}:/${BOOTSTRAP_NFS_PATH} $BOOTSTRAP_PATH && sudo -E /bin/bash $BOOTSTRAP_SCRIPT 2>&1 | sudo tee -a /var/log/bootstrap.log && sudo umount $BOOTSTRAP_PATH && sudo rmdir $BOOTSTRAP_PATH'
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

function mount_round_robin() {
    # to ensure the nodes are spread out somewhat evenly the default 
    # mount point is based on this node's IP octet4 % vFXT node count.
    declare -a AVEREVFXT_NODES="($(echo ${NFS_IP_CSV} | sed "s/,/ /g"))"
    OCTET4=$((`hostname -i | sed -e 's/^.*\.\([0-9]*\)/\1/'  | sed 's/[^0-9]*//g'`))
    DEFAULT_MOUNT_INDEX=$((${OCTET4} % ${#AVEREVFXT_NODES[@]}))
    ROUND_ROBIN_IP=${AVEREVFXT_NODES[${DEFAULT_MOUNT_INDEX}]}

    DEFAULT_MOUNT_POINT="${BASE_DIR}/default"

    # no need to write again if it is already there
    if ! grep --quiet "${DEFAULT_MOUNT_POINT}" /etc/fstab; then
        echo "${ROUND_ROBIN_IP}:${NFS_PATH}    ${DEFAULT_MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
        mkdir -p "${DEFAULT_MOUNT_POINT}"
        chown nfsnobody:nfsnobody "${DEFAULT_MOUNT_POINT}"
    fi
    if ! grep -qs "${DEFAULT_MOUNT_POINT} " /proc/mounts; then
        retrycmd_if_failure 12 20 mount "${DEFAULT_MOUNT_POINT}" || exit 1
    fi   
} 

function main() {
    echo "mount round robin default path"
    mount_round_robin

    # add extra bootstrap code here
}

main