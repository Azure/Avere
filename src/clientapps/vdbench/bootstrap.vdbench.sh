#!/bin/bash

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
        if grep -F --quiet "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}" /etc/fstab; then
            echo "not updating file, already there"
        else
            echo "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
            mount ${MOUNT_POINT}
        fi
        COUNTER=$(($COUNTER + 1))
    done
}

function install_vdbench() {
    DIRECTORY=/home/$LINUX_USER/vdbench
    if [ -d "$DIRECTORY" ]; then
      # already installed
      return 0
    fi
    mkdir -p $DIRECTORY
    pushd $DIRECTORY
    BOOTSTRAP_PATH="$(dirname ${BASE_DIR}${NODE_MOUNT_PREFIX}0${BOOTSTRAP_SCRIPT_PATH})"
    VDBENCHSRC="$BOOTSTRAP_PATH/vdbench*.zip"

    if ! ls $VDBENCHSRC > /dev/null 2>&1; then
        echo "MISSING: $VDBENCHSRC, please ensure the vdbench zip is downloaded to the bootstrap directory and reinstall."
        exit 1
    fi

    cp $VDBENCHSRC .
    unzip vdbench*.zip
    rm vdbench*.zip
    popd
    echo "chown -R $LINUX_USER:$LINUX_USER $DIRECTORY"
    chown -R $LINUX_USER:$LINUX_USER $DIRECTORY
}

function write_run_vdbench() {
    FILENAME=/home/$LINUX_USER/run_vdbench.sh
    /bin/cat <<EOM >$FILENAME
#!/usr/bin/env bash
CONF=\$1
UNIQ=\$2
JUNC=vdbench
/home/$LINUX_USER/vdbench/vdbench -f /home/$LINUX_USER/\${CONF} -o /home/$LINUX_USER/vdbench/output/\`date +%F\`_\${CONF}_\${UNIQ}
EOM
    chown $LINUX_USER:$LINUX_USER $FILENAME
    chmod +x $FILENAME
}

function write_copy_idrsa() {
    FILENAME=/home/$LINUX_USER/copy_idrsa.sh
    echo "#!/usr/bin/env bash" > "copy_idrsa.sh"
    COUNTER=0
    while [ $COUNTER -lt $NODE_COUNT ]; do
        echo "scp -o \"StrictHostKeyChecking no\" /home/$LINUX_USER/.ssh/id_rsa ${NODE_PREFIX}-${COUNTER}:.ssh/id_rsa" >> $FILENAME
        COUNTER=$[$COUNTER+1]
    done
    chown $LINUX_USER:$LINUX_USER $FILENAME
    chmod +x $FILENAME
}

function write_azure_clients() {
    FILENAME=/home/$LINUX_USER/azure-clients.conf
/bin/cat <<EOM >$FILENAME
hd=default,user=${LINUX_USER},shell=ssh
EOM
    # add each of the clients
    COUNTER=0
    while [ $COUNTER -lt $NODE_COUNT ]; do
        HOST_NUMBER=$(($COUNTER + 1))
        HOST_NUMBER_HEX=$( printf '%x' $HOST_NUMBER )
        NODE_NAME="${NODE_PREFIX}-${COUNTER}"
        IP=$( host ${NODE_NAME} | sed -e "s/.*\ //" )
        echo "NODE NAME ${NODE_NAME}, $IP"
        echo "hd=host${HOST_NUMBER_HEX},system=${IP}">>$FILENAME
        COUNTER=$[$COUNTER+1]
    done
    chown $LINUX_USER:$LINUX_USER $FILENAME
}

function write_inmem() {
    FILENAME=/home/$LINUX_USER/inmem.conf
    /bin/cat <<EOM >$FILENAME
create_anchors=yes
include=azure-clients.conf

fsd=default,depth=1,width=1,files=64,size=32m
EOM

    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        FSD_HOST="host-${COUNTER}"
        echo "fsd=fsd!${FSD_HOST},anchor=${MOUNT_POINT}/vdbench/!sizedir/!${FSD_HOST}" >> $FILENAME
        COUNTER=$(($COUNTER + 1))
    done

    /bin/cat <<EOM >>$FILENAME

fwd=default,xfersize=512k,fileio=sequential,fileselect=sequential,threads=24
fwd=fwdW!host,host=!host,fsd=(fsd!host*),operation=write,openflags=fsync
fwd=fwdR!host,host=!host,fsd=(fsd!host*),operation=read,openflags=o_direct

rd=default,elapsed=1080,fwdrate=max,interval=1,maxdata=72g
rd=makedirs1,fwd=(fwdWhost*),operations=(mkdir),maxdata=1m
rd=makefiles1,fwd=(fwdWhost*),operations=(create),maxdata=1m

rd=writefiles1,fwd=(fwdWhost*)
rd=writeread1,fwd=(fwdRhost*,fwdWhost*)
rd=readall1,fwd=(fwdRhost*)

rd=writefiles2,fwd=(fwdWhost*)
rd=writeread2,fwd=(fwdRhost*,fwdWhost*)
rd=readall2,fwd=(fwdRhost*),format=no

rd=writefiles3,fwd=(fwdWhost*)
rd=writeread3,fwd=(fwdRhost*,fwdWhost*)
rd=readall3,fwd=(fwdRhost*)
EOM
    chown $LINUX_USER:$LINUX_USER $FILENAME
}

function write_ondisk() {
    FILENAME=/home/$LINUX_USER/ondisk.conf
    /bin/cat <<EOM >$FILENAME
create_anchors=yes
include=azure-clients.conf

fsd=default,depth=1,width=1,files=180,size=32m
EOM

    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        FSD_HOST="host-${COUNTER}"
        echo "fsd=fsd!${FSD_HOST},anchor=${MOUNT_POINT}/!junction/!sizedir/!${FSD_HOST}" >> $FILENAME
        COUNTER=$(($COUNTER + 1))
    done

    /bin/cat <<EOM >>$FILENAME

fwd=format,threads=18,xfersize=512k,openflags=fsync
fwd=default,xfersize=512k,fileio=sequential,fileselect=sequential,threads=18
fwd=fwdW!host,host=!host,fsd=(fsd!host*),operation=write,openflags=fsync
fwd=fwdR!host,host=!host,fsd=(fsd!host*),operation=read,openflags=o_direct

rd=default,elapsed=10800,fwdrate=max,interval=1,maxdata=202.5g
rd=makedirs1,fwd=(fwdWhost*),operations=(mkdir),maxdata=1m
rd=makefiles1,fwd=(fwdWhost*),operations=(create),maxdata=1m

rd=writefiles1,fwd=(fwdWhost*)
rd=writeread1,fwd=(fwdRhost*,fwdWhost*)
rd=readall1,fwd=(fwdRhost*)

rd=writefiles2,fwd=(fwdWhost*)
rd=writeread2,fwd=(fwdRhost*,fwdWhost*)
rd=readall2,fwd=(fwdRhost*)

rd=writefiles3,fwd=(fwdWhost*)
rd=writeread3,fwd=(fwdRhost*,fwdWhost*)
rd=readall3,fwd=(fwdRhost*)
EOM
    chown $LINUX_USER:$LINUX_USER $FILENAME
}

function write_throughput() {
    FILENAME=/home/$LINUX_USER/throughput.conf
    /bin/cat <<EOM >$FILENAME
create_anchors=yes
include=azure-clients.conf

#N vFXT nodes ${NFS_IP_CSV}, 12 clients, 36 FSDs, 1TiB workingset
fsd=default,depth=1,width=1,files=180,size=160m
EOM

    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        FSD_HOST="host-${COUNTER}"
        echo "fsd=fsd!${FSD_HOST},anchor=${MOUNT_POINT}/sequential/!${FSD_HOST}" >> $FILENAME
        COUNTER=$(($COUNTER + 1))
    done

    /bin/cat <<EOM >>$FILENAME

fwd=format,threads=36,xfersize=512k,openflags=fsync
fwd=default,threads=36,xfersize=512k,fileio=sequential,fileselect=sequential
fwd=fwdW!host,host=!host,fsd=(fsd!host*),operation=write,openflags=fsync
fwd=fwdR!host,host=!host,fsd=(fsd!host*),operation=read,openflags=o_direct

rd=default,elapsed=10800,fwdrate=max,interval=1,maxdata=1012.5g
#rd=makedirs1,fwd=(fwdWhost*),operations=(mkdir),maxdata=1m
#rd=makefiles1,fwd=(fwdWhost*),operations=(create),maxdata=1m

rd=writefiles1,fwd=(fwdWhost*),format=restart
rd=writeread1,fwd=(fwdRhost*,fwdWhost*),format=no
rd=readall1,fwd=(fwdRhost*),format=no
rd=delall1,fwd=(fwdRhost*),operations=(delete),maxdata=1m
EOM
    chown $LINUX_USER:$LINUX_USER $FILENAME
}

function write_smallfileIO() {
    FILENAME=/home/$LINUX_USER/smallfileIO.conf
    /bin/cat <<EOM >$FILENAME
create_anchors=yes
include=azure-clients.conf

fsd=default,depth=1,width=10,files=1500,size=384k
EOM

    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        FSD_HOST="host-${COUNTER}"
        echo "fsd=fsd!${FSD_HOST},anchor=${MOUNT_POINT}/sequential/!${FSD_HOST}" >> $FILENAME
        COUNTER=$(($COUNTER + 1))
    done

    /bin/cat <<EOM >>$FILENAME

fwd=format,threads=48,xfersize=512k,openflags=fsync
fwd=default,xfersize=16k,fileio=random,fileselect=(sequential),threads=24
fwd=fwdrandW!host,host=!host,fsd=(fsd!host*),operation=write,openflags=o_direct,threads=48
fwd=fwdseqW!host,host=!host,fsd=(fsd!host*),operation=write,openflags=fsync,fileio=sequential,xfersize=512k
fwd=fwdrandR!host,host=!host,fsd=(fsd!host*),operation=read,openflags=o_direct
fwd=fwdseqR!host,host=!host,fsd=(fsd!host*),operation=read,openflags=o_direct,fileio=sequential,xfersize=512k

rd=default,elapsed=1800,fwdrate=max,interval=1,maxdata=202500m
rd=seqwritefsync1,fwd=(fwdseqWhost*),format=restart
rd=seqwritedirect1,fwd=(fwdseqWhost*),format=no
rd=randwrite2,fwd=(fwdrandWhost*),format=no,elapsed=900
rd=writeread1,fwd=(fwdrandRhost*,fwdrandWhost*),format=no
rd=randread1,fwd=(fwdrandRhost*),format=no
rd=seqreadcc1,fwd=(fwdseqRhost*),format=no
rd=seqreaddirect1,fwd=(fwdseqRhost*),format=no,openflags=o_direct
rd=deleteall1,fwd=(fwdRhost*),operations=(delete)
EOM
    chown $LINUX_USER:$LINUX_USER $FILENAME
}

function write_vdbench_files() {
    write_run_vdbench
    write_copy_idrsa
    write_azure_clients
    write_inmem
    write_ondisk
    write_throughput
    write_smallfileIO
}

function main() {
    echo "config Linux"
    config_linux

    echo "mount avere"
    mount_avere

    echo "install vdbench"
    install_vdbench

    echo "write vdbench files"
    write_vdbench_files

    echo "installation complete"
}

main

#test