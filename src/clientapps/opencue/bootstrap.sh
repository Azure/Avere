#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
#
# The following script mounts a default folder round robined across
# the vFXT ip addresses.
#
# Save this script to any Avere vFXT volume, for example:
#     /bootstrap/bootstrap.sh
#
# The following environment variables must be set:
#     NFS_IP_CSV="10.0.0.22,10.0.0.23,10.0.0.24"
#     NFS_PATH=/msazure
#     BASE_DIR=/nfs
#     CUEBOT_HOSTNAME="10.0.0.30"
#     CUEBOT_FS_ROOT=$BASE_DIR/opencue-demo
#
set -x
NODE_MOUNT_PREFIX="/node"

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

    DEFAULT_MOUNT_POINT="${BASE_DIR}/opencue-demo"

    # no need to write again if it is already there
    if ! grep --quiet "${DEFAULT_MOUNT_POINT}" /etc/fstab; then
        echo "${ROUND_ROBIN_IP}:${NFS_PATH}    ${DEFAULT_MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
        mkdir -p "${DEFAULT_MOUNT_POINT}"
        chown nobody:nogroup "${DEFAULT_MOUNT_POINT}"
    fi
    if ! grep -qs "${DEFAULT_MOUNT_POINT} " /proc/mounts; then
        retrycmd_if_failure 12 20 mount "${DEFAULT_MOUNT_POINT}" || exit 1
    fi
}

function mount_all() {
    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        echo "Mounting to ${VFXT}:${NFS_PATH} to ${MOUNT_POINT}"
        mkdir -p $MOUNT_POINT
        # no need to write again if it is already there
        if grep -F --quiet "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}" /etc/fstab; then
            echo "not updating file, already there"
        else
            echo "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
            retrycmd_if_failure 60 5 mount ${MOUNT_POINT}
            chmod 777 ${MOUNT_POINT}
        fi
        COUNTER=$(($COUNTER + 1))
    done
}

function main() {
    echo "mount round robin default path"
    if [ -z $MOUNT_ALL ]; then
        mount_round_robin
    else
        mount_all
    fi

    # Install PBRT on nodes
    # https://github.com/mmp/pbrt-v3/
    # cd ~
    # apt-get install -yq cmake build-essential gcc-4.8 g++-4.8 make bison flex libpthread-stubs0-dev
    # update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 40 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
    # git clone --recursive https://github.com/mmp/pbrt-v3/
    # mkdir pbrt
    # cd pbrt
    # cmake ../pbrt-v3/
    # make

    # Use pre-built pbrt tools
    echo "copy PBRT from cache to /opencue-tools/tools/pbrt-release/pbrt"
    mkdir /opencue-tools
    cp -r "${BASE_DIR}/opencue-demo/tools" /opencue-tools


    # Set up the RQD environment on each node
    # Based on https://www.opencue.io/docs/getting-started/deploying-rqd/
    echo "set up RQD server and connect to CueBot server"

    # yum based install
    # Update this for yum based installs...
    # yum -y install gcc
    # yum -y install python3-devel
    # yum -y install redhat-rpm-config
    # cd /usr/local/bin
    # pip3 install -r opencue-requirements.txt
    # tar -xzf opencue-rqd.tar.gz
    # find . -type f -name '*.pyc' -delete
    # cd rqd-*
    # python3 setup.py install
    
    # apt based install
    apt-get -y install python3 python3-dev python3-pip gcc
    cd ~
    echo "CUEBOT_HOSTNAME=$CUEBOT_HOSTNAME"
    echo "CUE_FS_ROOT=$CUE_FS_ROOT"
    wget "https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/rqd-0.4.14-all.tar.gz"
    export RQD_TARBALL="rqd-0.4.14-all.tar.gz"
    export RQD_DIR=$(basename "${RQD_TARBALL}" .tar.gz)
    tar zxvf "$RQD_TARBALL"
    cd "$RQD_DIR"
    pip3 install -r requirements.txt
    python3 setup.py install
    cd ..
    rm -rf "$RQD_DIR"
    # rqd &
    /usr/bin/nohup /bin/bash -c "rqd" > /dev/null 2>&1 &

    # add extra bootstrap and installation code here
    # this could be:
    #  - installation bash scripts
    #  - chef and puppet scripts
    #  - ansible scripts
    # when pulling content from the NFS server, ensure to use the round robin path, listed
    # under the default path, something similar to DEFAULT_MOUNT_POINT="${BASE_DIR}/default"
}

main