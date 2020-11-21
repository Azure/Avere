#!/bin/bash -x

# variables that must be set beforehand
# EXPORT_PATH=/data
#
# called like this:
#  sudo EXPORT_PATH=/data ./installnfs.sh
#

set -x

MOUNT_OPTIONS="noatime,nodiratime,nodev,noexec,nosuid,nofail"

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
        # timeout occasionally freezes
        #echo "timeout $timeout apt-get install --no-install-recommends -y ${@}"
        #timeout $timeout apt-get install --no-install-recommends -y ${@}
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
    add-apt-repository universe
	apt_get_update
	apt_get_install 20 10 180 nfs-ganesha nfs-ganesha-vfs
    # perf diagnostic tools
    if [ ! -z "$PERF_DIAG_TOOLS" ]; then
        apt_get_install 20 10 180 iotop iperf3 bwm-ng
    fi
    # enable root login, sometimes useful for rsync
    if [ ! -z "$ALLOW_ROOT_LOGIN" ]; then
        sed -i 's/.* ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys
        sed -i 's/^#PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart sshd
    fi
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function is_partitioned() {
    OUTPUT=$(partx -s ${1} 2>&1)
    egrep "partition table does not contains usable partitions|failed to read partition table" <<< "${OUTPUT}" >/dev/null 2>&1
    if [ ${?} -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function has_filesystem() {
    DEVICE=${1}
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # The disk will be considered a candidate for partitioning
        # and formatting if it does not have a sd?1 entry or
        # if it does have an sd?1 entry and does not contain a filesystem
        is_partitioned "${DEV}"
        if [ ${?} -eq 0 ];
        then
            has_filesystem "${DEV}1"
            if [ ${?} -ne 0 ];
            then
                RET+=" ${DEV}"
            fi
        else
            RET+=" ${DEV}"
        fi
    done
    echo "${RET}"
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function add_to_fstab() {
    UUID=${1}
    MOUNTPOINT=${2}
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=\"${UUID}\"\t${MOUNTPOINT}\text4\t${MOUNT_OPTIONS}\t1 2"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function do_partition() {
    # This function creates one (1) primary partition on the
    # disk, using all available space
    _disk=${1}
    _type=${2}
    if [ -z "${_type}" ]; then
        # default to Linux partition type (ie, ext3/ext4/xfs)
        _type=8300
    fi
    echo "n
1


${_type}
w
y"| gdisk "${_disk}"

    #
    # Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
    # from gdisk and not from echo
    if [ ${PIPESTATUS[1]} -ne 0 ];
    then
        echo "An error occurred partitioning ${_disk}" >&2
        echo "I cannot continue" >&2
        exit 2
    fi
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function scan_partition_format()
{
    echo "Begin scanning and formatting data disks"

    DISKS=($(scan_for_new_disks))

    if [ "${#DISKS[@]}" -eq 0 ];
    then
        echo "No unpartitioned disks without filesystems detected"
        return
    fi
    if [ "${#DISKS[@]}" -gt 1 ];
    then
        echo "WARNING: there are ${#DISKS[@]} unformatted disks, only the first disk will be mounted"
    fi
    echo "Disks are ${DISKS[@]}"
    DISK=${DISKS[0]}
    
    echo "Working on ${DISK}"
    is_partitioned ${DISK}
    if [ ${?} -ne 0 ];
    then
        echo "${DISK} is not partitioned, partitioning"
        do_partition ${DISK}
    fi
    PARTITION_NUM=$(gdisk -l ${DISK}|grep -A 1 Number|tail -n 1|awk '{print $1}')
    PARTITION=${DISK}${PARTITION_NUM}
    has_filesystem ${PARTITION}
    if [ ${?} -ne 0 ];
    then
        echo "Creating filesystem on ${PARTITION}."
        mkfs -j -t ext4 ${PARTITION}
    fi
}

function get_unmounted_disk()
{
    DEVS=($(ls -1 /dev/sd*|egrep "[a-z][0-9]$"))
    TARGET_PARTITION=""
    for DEV in "${DEVS[@]}";
    do
        if ! mount | grep -F --quiet "$DEV"; then
            TARGET_PARTITION=$DEV
            break
        fi
    done
    echo "$TARGET_PARTITION"
}

function mount_disk() {
    PARTITION=$1; shift

    MOUNTPOINT=$EXPORT_PATH
    echo "mount point is ${MOUNTPOINT}"
    if [ ! -d "${MOUNTPOINT}" ];
    then
        mkdir -p "${MOUNTPOINT}"
        chown nobody:nogroup "${MOUNTPOINT}"
        chmod 777 "${MOUNTPOINT}"
        ls -l "${MOUNTPOINT}"
    fi 
    read UUID FS_TYPE < <(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
    add_to_fstab "${UUID}" "${MOUNTPOINT}"
    echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
    mount "${MOUNTPOINT}"
}

function wait_for_disk_attach() {
    retries=$1; wait_sleep=$2; shift && shift

    for i in $(seq 1 $retries); do
        DISKS=($(scan_for_new_disks))
        if [ "${#DISKS[@]}" -gt 0 ]; then
            echo "new disk found!"
            return
        fi
        
        PARTITION=$(get_unmounted_disk)

        if [ ${#PARTITION} -gt 0 ]; then
            echo "unattached disk found!"
            return 
        fi

        echo "no disks found, sleeping for $wait_sleep seconds"
        sleep $wait_sleep
    done
}

# export the ephemeral disk as specified by $EXPORT_PATH
function configure_nfs() {
    # enable the nfs service
    systemctl enable nfs-ganesha

    # stop the nfs service
    systemctl stop nfs-ganesha

    cp /etc/ganesha/ganesha.conf /etc/ganesha/ganesha.conf.bak
    
    echo "EXPORT
{
        # Export Id (mandatory, each EXPORT must have a unique Export_Id)
        Export_Id = 87;

        # Exported path (mandatory)
        Path = ${EXPORT_PATH};

        # Pseudo Path (required for NFS v4)
        Pseudo = ${EXPORT_PATH};

        # Required for access (default is None)
        # Could use CLIENT blocks instead
        Access_Type = RW;

        # Exporting FSAL
        FSAL {
                Name = VFS;
        }
        CLIENT {
                Access_Type=RW;
                Anonymous_gid=4294967294;
                Anonymous_uid=4294967294;
                Clients=*;
                Delegations=none;
                Manage_Gids=FALSE;
                NFS_Commit=FALSE;
                PrivilegedPort=FALSE;
                Protocols= 3,4;
                SecType=NONE,SYS;
                Squash=NO_ROOT_SQUASH;
                Transports=UDP,TCP;
        }
}" > /etc/ganesha/ganesha.conf
    
    # start the nfs service
    systemctl start nfs-ganesha
}

function main() {
    mkdir -p /opt
    
    if [ -z "$EXPORT_PATH" ]; then
        echo "env var EXPORT_PATH is not defined, please define"
        touch /opt/installnfs.failed
        touch /opt/installnfs.complete
        exit 1
    fi

    echo "config Linux"
    config_linux

    # wait 10 minutes for a disk to show up
    wait_for_disk_attach 60 10
    
    echo "scan_partition_format"
    scan_partition_format

    echo "mount_unmounted_disk"
    PARTITION=$(get_unmounted_disk)

    if [ ${#PARTITION} -eq 0 ]; then
        echo "no unmounted file system exists"
        touch /opt/installnfs.failed
        touch /opt/installnfs.complete
        return 1
    fi

    mount_disk $PARTITION

    echo "setup NFS Server"
    configure_nfs
    
    echo "installation complete"
    touch /opt/installnfs.complete
}

main
