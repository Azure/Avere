#!/bin/bash -x

# variables that must be set beforehand
# EXPORT_PATH=/data
# EXPORT_OPTIONS="*(rw,sync,no_root_squash)"
#
# called like this:
#  sudo EXPORT_PATH=/data EXPORT_OPTIONS="*(rw,sync,no_root_squash)" ./installnfs.sh
#

# terraform variables: tf_env_variables

set -x

function yum_install() {
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        yum install -y ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo "failed"
            touch /opt/installnfs.failed
            exit 1
        else
            sleep $wait_sleep
        fi
    done
    echo "completed"
    echo Executed yum install -y \"$@\" $i times;

    yum install -y nfs-utils
}

function config_linux() {
    yum_install 20 10 180 nfs-utils
}

function config_ephemeral_nvme {
    RAIDDISK=/dev/md0
    DISKS=($(ls /dev/nvme*n*))
    DISKCOUNT=${#DISKS[@]}
    if [ "$DISKCOUNT" -eq "1" ] ; then
        DISK_DEVICE=${DISKS[0]}
    else
        udevadm control --stop-exec-queue
        echo "yes" | mdadm --create $RAIDDISK --level=0 --raid-devices=$DISKCOUNT ${DISKS[@]}
        udevadm control --start-exec-queue
        mkdir -p /etc/mdadm
        mdadm --detail --verbose --scan > /etc/mdadm/mdadm.conf
        # log the details of the mount to STDOUT
        mdadm --detail --verbose --scan
        cat /proc/mdstat
        DISK_DEVICE=$RAIDDISK
    fi

    # add the ext4 filesystem
    mkfs.ext4 -F $DISK_DEVICE

    read UUID FS_TYPE < <(blkid -u filesystem $DISK_DEVICE|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
    echo -e "UUID=\"${UUID}\"\t$EXPORT_PATH\t$FS_TYPE\tnoatime,nodiratime,nodev,noexec,nosuid,nofail\t1 2" >> /etc/fstab
    mount $EXPORT_PATH
}

function config_ephemeral_ssd {
    grep -e "/mnt\s" /etc/fstab > /dev/null 2>&1
    if [ $? = "0" ]; then
        # this is managed by the new cloud init

        # export the ephemeral disk
        EPHEMERAL_DISK_PATH="/mnt"
        umount $EPHEMERAL_DISK_PATH
        sed -i "s:${EPHEMERAL_DISK_PATH}:${EXPORT_PATH}:g" /etc/fstab
        mount ${EXPORT_PATH}
    else 
        # this is managed by older waagent

        # export the ephemeral disk
        EPHEMERAL_DISK_PATH="/mnt/resource"
        # move the ephemeral mount to the mount chosen by the customer
        # we cannot do the symbolic link because it is not supported by nfsv4
        umount $EPHEMERAL_DISK_PATH
        sed -i "s:${EPHEMERAL_DISK_PATH}:${EXPORT_PATH}:g" /etc/waagent.conf
        # restart waagent to mount the new share
        systemctl restart waagent
    fi
}

function config_ephemeral_disk {
    mkdir -p $EXPORT_PATH
    grep nfsnobody /etc/passwd > /dev/null 2>&1
    if [ $? = "0" ]; then
        chown nfsnobody:nfsnobody $EXPORT_PATH
    else
        chown nobody:nogroup $EXPORT_PATH
    fi
    chmod 777 $EXPORT_PATH

    ls -1 /dev/nvme*
    if [ $? = "0" ]; then
        config_ephemeral_nvme
    else
        config_ephemeral_ssd
    fi
}

# export the ephemeral disk as specified by $EXPORT_PATH
function configure_nfs() {
    # enable the nfs service
    systemctl enable nfs-server rpcbind

    # stop the nfs service
    systemctl stop nfs-server rpcbind

    # configure NFS export for the export path
    grep "^${EXPORT_PATH}" /etc/exports > /dev/null 2>&1
    if [ $? = "0" ]; then
        echo "${EXPORT_PATH} is already exported. Returning..."
    else
        echo -e "\n${EXPORT_PATH}   ${EXPORT_OPTIONS}" >> /etc/exports
    fi

    # update to use 64 threads to get most performance
    sed -i 's/^.*RPCNFSDCOUNT=.*$/RPCNFSDCOUNT=64/g' /etc/sysconfig/nfs
    
    # start the nfs service
    systemctl start nfs-server rpcbind
}

function main() {
    mkdir -p /opt
    
    if [ -z "$EXPORT_PATH" ]; then
        echo "env var EXPORT_PATH is not defined, please define"
        touch /opt/installnfs.failed
        exit 1
    fi

    if [ -z "$EXPORT_OPTIONS" ]; then
        echo "env var EXPORT_OPTIONS is not defined, please define"
        touch /opt/installnfs.failed
        exit 1
    fi

    echo "config Linux"
    config_linux

    echo "config Ephemeral Disk"
    config_ephemeral_disk

    echo "setup NFS Server"
    configure_nfs
    
    echo "installation complete"

    touch /opt/installnfs.complete
}

main
