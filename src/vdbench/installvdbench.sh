#!/bin/bash

# variables that must be set beforehand
#NODE_PREFIX=avereclient
#NODE_COUNT=3
#LINUX_USER=azureuser
#AVEREVFXT_NODE_IPS="172.16.1.8,172.16.1.9,172.16.1.10"
#
# called like this:
#  sudo NODE_PREFIX=avereclient NODE_COUNT=3 LINUX_USER=azureuser AVEREVFXT_NODE_IPS="172.16.1.8,172.16.1.9,172.16.1.10" ./install.sh
#
function retrycmd_if_failure() {
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        timeout $timeout ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            return 1
        else
            sleep $wait_sleep
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
	#hostname=`hostname -s`
	#sudo sed -ie "s/127.0.0.1 localhost/127.0.0.1 localhost ${hostname}/" /etc/hosts
	export DEBIAN_FRONTEND=noninteractive  
	apt_get_update
	apt_get_install 20 10 180 default-jre zip nfs-common csh unzip
}

function mount_avere() {
    COUNTER=1
    for VFXT in $(echo $AVEREVFXT_NODE_IPS | sed "s/,/ /g")
    do
        MOUNT_POINT="/mnt/node${COUNTER}"
        echo "Mounting to $VFXT:msazure to ${MOUNT_POINT}"
        sudo mkdir -p $MOUNT_POINT
        # no need to write again if it is already there
        if grep -v --quiet $VFXT /etc/fstab; then
            echo "$VFXT:/msazure	${MOUNT_POINT}	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" >> /etc/fstab
            sudo mount ${MOUNT_POINT}
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
	mkdir $DIRECTORY
	pushd $DIRECTORY
    echo "curl -sSL -o vdbench50407.zip https://download.averesystems.com/software/vdbench50407.zip"
	retrycmd_if_failure 10 5 180 curl -sSL -o vdbench50407.zip https://download.averesystems.com/software/vdbench50407.zip
	unzip vdbench50407.zip
	rm vdbench50407.zip
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
    COUNTER=1
    while [ $COUNTER -lt $NODE_COUNT ]; do
        echo "scp -o \"StrictHostKeyChecking no\" /home/$LINUX_USER/.ssh/id_rsa ${NODE_PREFIX}${COUNTER}:.ssh/id_rsa" >> $FILENAME
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
        NODE_NAME="${NODE_PREFIX}${COUNTER}"
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

    COUNTER=1
    for VFXT in $(echo $AVEREVFXT_NODE_IPS | sed "s/,/ /g")
    do
        MOUNT_POINT="/mnt/node${COUNTER}"
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

    COUNTER=1
    for VFXT in $(echo $AVEREVFXT_NODE_IPS | sed "s/,/ /g")
    do
        MOUNT_POINT="/mnt/node${COUNTER}"
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

function write_vdbench_files() {
	write_run_vdbench
    write_copy_idrsa
	write_azure_clients
	write_inmem
	write_ondisk
}

echo "config Linux"
config_linux
echo "mount avere"
mount_avere
echo "install vdbench"
install_vdbench
echo "write vdbench files"
write_vdbench_files
echo "installation complete"
