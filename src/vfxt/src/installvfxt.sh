#!/bin/bash

# report all lines, and exit on error
set -x
set -e

ARM_TRUE="True"
WAIT_SECONDS=600
AZURE_HOME_DIR=/home/$CONTROLLER_ADMIN_USER_NAME
VFXT_INSTALL_TEMPLATE=$AZURE_HOME_DIR/vfxtinstall
CLOUD_BACKED_TEMPLATE=/create-cloudbacked-cluster
MINIMAL_TEMPLATE=/create-minimal-cluster
VFXT_LOG_FILE=$AZURE_HOME_DIR/vfxt.log
ARM_ENDPOINT=https://management.azure.com/metadata/endpoints?api-version=2017-12-01

function retrycmd_if_failure() {
    set +e
    retries=$1; wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            set -e
            return 1
        else
            sleep $wait_sleep
        fi
    done
    set -e
    echo Executed \"$@\" $i times;
}

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

function wait_arm_endpoint() {
    # ensure the arm endpoint is reachable
    # https://docs.microsoft.com/en-us/azure/virtual-machines/windows/instance-metadata-service#getting-azure-environment-where-the-vm-is-running
    if ! retrycmd_if_failure 24 5 curl -m 5 -o /dev/null $ARM_ENDPOINT ; then
        echo "no internet! arm endpoint $ARM_ENDPOINT not reachable.  Please see https://github.com/Azure/Avere/tree/main/src/vfxt#internet-access on how to configure firewall, dns, or proxy."
        exit 1
    fi
}

function wait_az_login_and_vnet() {
    # wait for RBAC assignments to be applied
    # unfortunately, the RBAC assignments take undetermined time past their associated resource completions to be assigned.
    if ! retrycmd_if_failure 120 5 az login --identity ; then
        echo "MANAGED IDENTITY FAILURE: failed to login after waiting 10 minutes, this is managed identity bug"
        exit 1
    fi
    if ! retrycmd_if_failure 12 5 az account set --subscription $SUBSCRIPTION_ID ; then
        echo "MANAGED IDENTITY FAILURE: failed to set subscription"
        exit 1
    fi
    if ! retrycmd_if_failure 120 5 az network vnet subnet list -g $NETWORK_RESOURCE_GROUP --vnet-name $NETWORK ; then
        echo "RBAC ASSIGNMENT FAILURE: failed to list vnet after waiting 10 minutes, this is rbac assignment bug"
        exit 1
    fi
}

function configure_vfxt_template() {
    if [ "$CREATE_CLOUD_BACKED_CLUSTER" == "$ARM_TRUE" ]; then
        cp $CLOUD_BACKED_TEMPLATE $VFXT_INSTALL_TEMPLATE
    else
        cp $MINIMAL_TEMPLATE $VFXT_INSTALL_TEMPLATE
    fi

    # update the internal variables
    sed -i 's/^RESOURCE_GROUP/#RESOURCE_GROUP/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^LOCATION/#LOCATION/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^NETWORK/#NETWORK/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^SUBNET/#SUBNET/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^AVERE_CLUSTER_ROLE/#AVERE_CLUSTER_ROLE/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^STORAGE_ACCOUNT/#STORAGE_ACCOUNT/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^CACHE_SIZE/#CACHE_SIZE/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^CLUSTER_NAME/#CLUSTER_NAME/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^ADMIN_PASSWORD/#ADMIN_PASSWORD/g' $VFXT_INSTALL_TEMPLATE
    sed -i 's/^INSTANCE_TYPE/#INSTANCE_TYPE/g' $VFXT_INSTALL_TEMPLATE
    # replace "--from-environment" with "--on-instance" since we are using
    sed -i 's/ --from-environment / --on-instance /g' $VFXT_INSTALL_TEMPLATE
    sed -i "s:~/vfxt.log:$VFXT_LOG_FILE:g"  $VFXT_INSTALL_TEMPLATE
    # do not trace password in log, instead the command is captured in file ~/create_cluster_command.log, with password correctly redacted
    sed -i "s/^set -exu/set -eu/g"  $VFXT_INSTALL_TEMPLATE
}

function create_vfxt() {
    #######################################################
    # do not trace passwords
    #######################################################
    set -x
    #######################################################

    cd $AZURE_HOME_DIR
    # enable cloud trace during installation
    if [ "${ENABLE_CLOUD_TRACE_DEBUG}" == "${ARM_TRUE}" ] ; then
        nohup /bin/bash /opt/avere/enablecloudtrace.sh > $AZURE_HOME_DIR/enablecloudtrace.log 2>&1 &
    fi
    # ensure the create cluster command is recorded for the future
    sleep 2 && ps -a -x -o cmd | egrep '[v]fxt.py' |  sed 's/--admin-password [^ ]*/--admin-password ***/' > create_cluster_command.log &
    $VFXT_INSTALL_TEMPLATE

    #######################################################
    # re-enable tracing
    #######################################################
    set +x
    #######################################################
}

function print_vfxt_vars() {
    echo "VSERVER_IPS=$(sed -n "s/^.*Creating vserver vserver (\(.*\)\/255.255.255.255).*$/\1/p" $VFXT_LOG_FILE)"
    echo "MGMT_IP=$(sed -n "s/^.*management address: \(.*\)/\1/p" $VFXT_LOG_FILE)"
}

function dump_env_vars() {
    echo "start env dump"
    echo $(pwd)
    echo "export RESOURCE_GROUP=$RESOURCE_GROUP"
    echo "export LOCATION=$LOCATION"
    echo "export NETWORK_RESOURCE_GROUP=$NETWORK_RESOURCE_GROUP"
    echo "export NETWORK=$NETWORK"
    echo "export SUBNET=$SUBNET"
    echo "export AVERE_CLUSTER_ROLE=$AVERE_CLUSTER_ROLE"
    echo "export CREATE_CLOUD_BACKED_CLUSTER=$CREATE_CLOUD_BACKED_CLUSTER"
    echo "export STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
    echo "export CACHE_SIZE=$CACHE_SIZE"
    echo "export CLUSTER_NAME=$CLUSTER_NAME"
    echo "export INSTANCE_TYPE=$INSTANCE_TYPE"
    echo "export ADMIN_PASSWORD=$ADMIN_PASSWORD"
    echo "finish env dump"
}

function apt_get_update() {
    set +e
    retries=10
    apt_update_output=/tmp/apt-get-update.out
    for i in $(seq 1 $retries); do
        timeout 300 apt-get update 2>&1
        [ $? -eq 0  ] && break
        if [ $i -eq $retries ]; then
            set -e
            return 1
        else sleep 30
        fi
    done
    set +e
    echo Executed apt-get update $i times
}

function apt_get_install() {
    set +e
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        # timeout occasionally freezes
        #echo "timeout $timeout apt-get install --no-install-recommends -y ${@}"
        #timeout $timeout apt-get install --no-install-recommends -y ${@}
        apt-get install --no-install-recommends -y ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            set -e
            return 1
        else
            sleep $wait_sleep
            apt_get_update
        fi
    done
    set -e
    echo Executed apt-get install --no-install-recommends -y \"$@\" $i times;
}

function config_linux() {
    #hostname=`hostname -s`
    #sudo sed -ie "s/127.0.0.1 localhost/127.0.0.1 localhost ${hostname}/" /etc/hosts
    export DEBIAN_FRONTEND=noninteractive
    apt_get_update
    apt_get_install 20 10 180 curl dirmngr python-pip nfs-common build-essential python-dev python-setuptools
    # this is no longer need because it is not longer there (mar 2019 ubuntu)
    # retrycmd_if_failure 12 5 apt remove --purge -y python-keyring
    retrycmd_if_failure 12 5 pip install --requirement /opt/avere/python_requirements.txt
}

function install_vfxt() {
    retrycmd_if_failure 12 5 pip install --no-deps vFXT
}

function install_vfxt_py_docs() {
    pushd / &>/dev/null
    curl --retry 5 --retry-delay 5 -o vfxtdistdoc.tgz https://averedistribution.blob.core.windows.net/public/vfxtdistdoc.tgz &>/dev/null || true
    if [ -f vfxtdistdoc.tgz ]; then
            tar --no-same-owner -xf vfxtdistdoc.tgz
            rm -f vfxtdistdoc.tgz
    fi
    popd &>/dev/null
}

function main() {
    # ensure waagent upgrade does not interrupt this CSE
    retrycmd_if_failure 240 5 apt-mark hold walinuxagent

    echo "wait arm endpoint"
    wait_arm_endpoint

    echo "wait azure home dir"
    wait_azure_home_dir

    if [ "$BUILD_CONTROLLER" == "$ARM_TRUE" ]; then
        echo "configure linux"
        config_linux

        echo "install_vfxt_py"
        install_vfxt

        echo "install_vfxt_docs"
        install_vfxt_py_docs
    fi

    echo "wait az login"
    wait_az_login_and_vnet

    #echo "dump env vars for debugging"
    #dump_env_vars

    echo "configure vfxt install template"
    configure_vfxt_template

    echo "create_vfxt"
    create_vfxt

    echo "print vfxt vars"
    print_vfxt_vars

    # ensure waagent upgrade can proceed
    retrycmd_if_failure 300 15 apt-mark unhold walinuxagent

    echo "installation complete"
}

main
