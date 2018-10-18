#!/bin/bash -x

#
# The following script mounts a default round robin's across the
# vFXT ip addresses.
#

# the comma separated Avere vFXT vServer IP addresses
export NFS_IP_CSV="10.0.0.22,10.0.0.23,10.0.0.24"
export TARGET_IP_EASTUS=192.168.255.4
export TARGET_IP_WESTUS=192.168.255.20
export TARGET_IP_WESTINDIA=192.168.255.52
export TARGET_IP_SOUTHEASTASIA=192.168.255.36

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

function mount_target() {
    NFS_PATH=$1
    TARGET_MOUNT_POINT=$2
    TARGET_IP=$3
    if ! grep --quiet "${TARGET_IP}:${NFS_PATH}" /etc/fstab; then
        echo "${TARGET_IP}:${NFS_PATH}    ${TARGET_MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
        mkdir -p "${TARGET_MOUNT_POINT}"
        chown nfsnobody:nfsnobody "${TARGET_MOUNT_POINT}"
    fi
    if ! grep -qs "${TARGET_MOUNT_POINT} " /proc/mounts; then
        retrycmd_if_failure 12 20 mount "${TARGET_MOUNT_POINT}" || exit 1
    fi
}

function mount_round_robin_e32() {
    # to ensure the nodes are spread out somewhat evenly the default
    # mount point is based on this node's IP octet4 % vFXT node count.
    declare -a AVEREVFXT_NODES="($(echo ${NFS_IP_CSV} | sed "s/,/ /g"))"
    OCTET4=$((`hostname -i | sed -e 's/^.*\.\([0-9]*\)/\1/'`))
    DEFAULT_MOUNT_INDEX=$((${OCTET4} % ${#AVEREVFXT_NODES[@]}))
    ROUND_ROBIN_IP=${AVEREVFXT_NODES[${DEFAULT_MOUNT_INDEX}]}

    NFS_PATH="/eastus"
    TARGET_MOUNT_POINT="/nfs/${NFS_PATH}vfxt"
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $ROUND_ROBIN_IP

    NFS_PATH="/westus"
    TARGET_MOUNT_POINT="/nfs/${NFS_PATH}vfxt"
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $ROUND_ROBIN_IP
    
    NFS_PATH="/westindia"
    TARGET_MOUNT_POINT="/nfs/${NFS_PATH}vfxt"
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $ROUND_ROBIN_IP
    
    NFS_PATH="/southeastasia"
    TARGET_MOUNT_POINT="/nfs/${NFS_PATH}vfxt"
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $ROUND_ROBIN_IP
}

function mount_regional_cluster() {
    # no need to write again if it is already there
    NFS_PATH=/datadisks/disk1
    
    TARGET_MOUNT_POINT=/nfs/eastus
    TARGET_IP=$TARGET_IP_EASTUS
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $TARGET_IP
    
    TARGET_MOUNT_POINT=/nfs/westus
    TARGET_IP=$TARGET_IP_WESTUS
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $TARGET_IP
    
    TARGET_MOUNT_POINT=/nfs/westindia
    TARGET_IP=$TARGET_IP_WESTINDIA
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $TARGET_IP
    
    TARGET_MOUNT_POINT=/nfs/southeastasia
    TARGET_IP=$TARGET_IP_SOUTHEASTASIA
    mount_target $NFS_PATH $TARGET_MOUNT_POINT $TARGET_IP
}

function main() {
    echo "mount the regional cluster"
    mount_regional_cluster

    echo "mount round robin the e32 vfxt default path"
    mount_round_robin_e32

    # add extra bootstrap code here
}

main
