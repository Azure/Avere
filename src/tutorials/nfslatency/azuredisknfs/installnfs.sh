#!/bin/bash -x

# variables that must be set beforehand
# DATA_BASE=/datadisks
#
# called like this:
#  sudo DATA_BASE=/datadisks ./installnfs.sh
#

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
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            return 1
        else
            sleep $wait_sleep
            apt_get_update
        fi
    done
    echo "completed"
    echo Executed apt-get install --no-install-recommends -y \"$@\" $i times;
}

function config_linux() {
	#hostname=`hostname -s`
	#sudo sed -ie "s/127.0.0.1 localhost/127.0.0.1 localhost ${hostname}/" /etc/hosts
	export DEBIAN_FRONTEND=noninteractive  
	apt_get_update
	apt_get_install 20 10 180 nfs-kernel-server nfs-common
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
add_to_fstab() {
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
        _type=83
    fi
    echo "n
p
1


t
${_type}
w"| fdisk "${_disk}"

    #
    # Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
    # from fdisk and not from echo
    if [ ${PIPESTATUS[1]} -ne 0 ];
    then
        echo "An error occurred partitioning ${_disk}" >&2
        echo "I cannot continue" >&2
        exit 2
    fi
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
get_next_mountpoint() {
    DIRS=$(ls -1d ${DATA_BASE}/disk* 2>/dev/null| sort --version-sort)
    MAX=$(echo "${DIRS}"|tail -n 1 | tr -d "[a-zA-Z/]")
    if [ -z "${MAX}" ];
    then
        echo "${DATA_BASE}/disk1"
        return
    fi
    IDX=1
    while [ "${IDX}" -lt "${MAX}" ];
    do
        NEXT_DIR="${DATA_BASE}/disk${IDX}"
        if [ ! -d "${NEXT_DIR}" ];
        then
            echo "${NEXT_DIR}"
            return
        fi
        IDX=$(( ${IDX} + 1 ))
    done
    IDX=$(( ${MAX} + 1))
    echo "${DATA_BASE}/disk${IDX}"
}

# source from https://github.com/Azure/azure-quickstart-templates/blob/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
function scan_partition_format()
{
    echo "Begin scanning and formatting data disks"

    DISKS=($(scan_for_new_disks))

	if [ "${#DISKS}" -eq 0 ];
	then
	    echo "No unpartitioned disks without filesystems detected"
	    return
	fi
	echo "Disks are ${DISKS[@]}"
	for DISK in "${DISKS[@]}";
	do
	    echo "Working on ${DISK}"
	    is_partitioned ${DISK}
	    if [ ${?} -ne 0 ];
	    then
	        echo "${DISK} is not partitioned, partitioning"
	        do_partition ${DISK}
	    fi
	    PARTITION=$(fdisk -l ${DISK}|grep -A 1 Device|tail -n 1|awk '{print $1}')
	    has_filesystem ${PARTITION}
	    if [ ${?} -ne 0 ];
	    then
	        echo "Creating filesystem on ${PARTITION}."
	        mkfs -j -t ext4 ${PARTITION}
	    fi
	    MOUNTPOINT=$(get_next_mountpoint)
	    echo "Next mount point appears to be ${MOUNTPOINT}"
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
	done
}

# export all the disks under ${DATA_BASE} for NFS
function configure_nfs() {
    DIRS=$(ls -1d ${DATA_BASE}/disk* 2>/dev/null| sort --version-sort)
    for MOUNTPOINT in "${DIRS[@]}";
	do
        # configure NFS export for the disk
        grep "^${MOUNTPOINT}" /etc/exports > /dev/null 2>&1
        if [ $? = "0" ]; then
            echo "${MOUNTPOINT} is already exported. Returning..."
        else
            echo -e "\n${MOUNTPOINT}   *(rw,sync,no_root_squash)" >> /etc/exports
        fi
    done
    
    systemctl enable nfs-kernel-server.service
    systemctl restart nfs-kernel-server.service
}

function main() {
    echo "config Linux"
    config_linux

    echo "scan_partition_format"
    scan_partition_format

    echo "setup NFS Server"
    configure_nfs
    
    echo "installation complete"
}

main
