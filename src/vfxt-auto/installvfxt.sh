#!/bin/bash -x

ARM_TRUE="True"
WAIT_SECONDS=600
AZURE_HOME_DIR=/home/$CONTROLLER_ADMIN_USER_NAME
VFXT_INSTALL_TEMPLATE=$AZURE_HOME_DIR/vfxtinstall
CLOUD_BACKED_TEMPLATE=/create-cloudbacked-cluster
MINIMAL_TEMPLATE=/create-minimal-cluster

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

function setup_az() {
    az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
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
    sed -i "s:~/vfxt.log:$AZURE_HOME_DIR/vfxt.log:g"  $VFXT_INSTALL_TEMPLATE
}

function create_vfxt() {
    cd AZURE_HOME_DIR
    $VFXT_INSTALL_TEMPLATE
}

function dump_env_vars() {
    echo "start env dump"
    echo $(pwd)
    echo "export AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
    echo "export AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET"
    echo "export AZURE_TENANT_ID=$AZURE_TENANT_ID"
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

function main() {
    echo "wait azure home dir"
    wait_azure_home_dir

    echo "setup az"
    setup_az

    echo "configure vfxt install template"
    configure_vfxt_template

    echo "create_vfxt"
    create_vfxt

    #echo "dump env vars for debugging"
    #dump_env_vars
    
    echo "installation complete"
}

main
