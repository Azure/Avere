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
    retrycmd_if_failure 12 5 yum -y install wget unzip git
}

function install_golang() {
    cd $AZURE_HOME_DIR/.
    GO_DL_FILE=go1.14.linux-amd64.tar.gz
    retrycmd_if_failure 12 5 wget https://dl.google.com/go/$GO_DL_FILE
    tar xvf $GO_DL_FILE
    chown -R $ADMIN_USER_NAME:$ADMIN_USER_NAME ./go
    mkdir -p $AZURE_HOME_DIR/gopath
    chown -R $ADMIN_USER_NAME:$ADMIN_USER_NAME $AZURE_HOME_DIR/gopath
    echo "export GOPATH=$AZURE_HOME_DIR/gopath" >> $AZURE_HOME_DIR/.bashrc
    echo "export PATH=\$GOPATH/bin:$AZURE_HOME_DIR/go/bin:$PATH" >> $AZURE_HOME_DIR/.bashrc
    echo "export GOROOT=$AZURE_HOME_DIR/go" >> $AZURE_HOME_DIR/.bashrc
    rm $GO_DL_FILE
}

function pull_avere_github() {
    # best effort to build the github content
    set +e
    # setup the environment
    source $AZURE_HOME_DIR/.bashrc
    OLD_HOME=$HOME
    export HOME=$AZURE_HOME_DIR
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    cd src/github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    go mod download
    go mod tidy
    go build
    mkdir -p $AZURE_HOME_DIR/.terraform.d/plugins
    cp terraform-provider-avere $AZURE_HOME_DIR/.terraform.d/plugins
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
    retrycmd_if_failure 12 5 wget https://releases.hashicorp.com/terraform/0.12.21/terraform_0.12.21_linux_amd64.zip
    unzip terraform_0.12.21_linux_amd64.zip -d /usr/local/bin
    rm terraform_0.12.21_linux_amd64.zip
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "install golang"
    install_golang

    echo "pull and build the Avere github project"
    pull_avere_github

    echo "install az cli"
    install_az_cli

    echo "install terraform"
    install_terraform

    echo "installation complete"
    touch /opt/install.completed
}

main