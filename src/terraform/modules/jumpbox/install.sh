#!/bin/bash

# report all lines, and exit on error
set -x
set -e

AZURE_HOME_DIR=/home/$ADMIN_USER_NAME

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

function update_linux() {
    retrycmd_if_failure 12 5 yum -y install wget unzip git nfs-utils tmux nc jq
    retrycmd_if_failure 12 5 yum -y install epel-release
    retrycmd_if_failure 12 5 yum -y install python-pip
    #retrycmd_if_failure 3 5 pip install hstk
}

function install_golang() {
    cd $AZURE_HOME_DIR
    GO_DL_FILE=go1.16.6.linux-amd64.tar.gz
    wget --tries=12 --wait=5 https://dl.google.com/go/$GO_DL_FILE
    sudo tar -C /usr/local -xzf $GO_DL_FILE
    rm -f $GO_DL_FILE
    #echo "export GOPATH=$AZURE_HOME_DIR/gopath" >> $AZURE_HOME_DIR/.profile
    echo "export PATH=$PATH:/usr/local/go/bin" >> $AZURE_HOME_DIR/.profile
}

function pull_avere_github() {
    # use workaround set home for go to work, bug here: https://github.com/golang/go/issues/43938
    OLD_HOME=$HOME
    export HOME=$AZURE_HOME_DIR

    # best effort to build the github content
    set +e
    RELEASE_DIR=$AZURE_HOME_DIR/releases
    mkdir -p $RELEASE_DIR
    source $AZURE_HOME_DIR/.profile
    cd $AZURE_HOME_DIR
    git clone https://github.com/Azure/Avere.git
    
    # build the provider
    cd $AZURE_HOME_DIR/Avere/src/terraform/providers/terraform-provider-avere
    go build
    GOOS=windows GOARCH=amd64 go build
    mv terraform-provider-avere* $RELEASE_DIR/.
    
    # build the cachewarmer
    cd $AZURE_HOME_DIR/Avere/src/go/cmd/cachewarmer/cachewarmer-jobsubmitter
    go build
    mv cachewarmer-jobsubmitter $RELEASE_DIR/.
    cd $AZURE_HOME_DIR/Avere/src/go/cmd/cachewarmer/cachewarmer-manager
    go build
    mv cachewarmer-manager $RELEASE_DIR/.
    cd $AZURE_HOME_DIR/Avere/src/go/cmd/cachewarmer/cachewarmer-worker
    go build
    mv cachewarmer-worker $RELEASE_DIR/.
    
    cd $RELEASE_DIR/.
    ls -lh

    # install provider
    version=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name | sed -e 's/[^0-9]*\([0-9].*\)$/\1/')
    echo $version
    mkdir -p $AZURE_HOME_DIR/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
    cp $RELEASE_DIR/terraform-provider-avere $AZURE_HOME_DIR/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64

    # restore HOME
    export HOME=$OLD_HOME

    # re-enable exit on error
    set -e
}

function install_az_cli() {
    retrycmd_if_failure 12 5 rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
    retrycmd_if_failure 12 5 yum -y install azure-cli
}

function install_terraform() {
    cd $AZURE_HOME_DIR/.
    wget --tries=12 --wait=5 https://releases.hashicorp.com/terraform/1.0.2/terraform_1.0.2_linux_amd64.zip
    unzip terraform_1.0.2_linux_amd64.zip -d /usr/local/bin
    rm terraform_1.0.2_linux_amd64.zip
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    if [ "${BUILD_VFXT_PROVIDER}" = "true" ]; then
        echo "install golang"
        install_golang

        echo "pull and build the Avere github project"
        pull_avere_github
    fi

    echo "install az cli"
    install_az_cli

    echo "install terraform"
    install_terraform

    echo "installation complete"
    touch /opt/install.completed
}

main
