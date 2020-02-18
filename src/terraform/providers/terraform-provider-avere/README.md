# Terraform Avere vFXT Provider

This directory contains the code to build a provider for the Avere vFXT for Azure.

The provider has the following features:
* create / destroy the Avere vFXT cluster
* scale-up / scale-down from 3 to 16 nodes
* add or remove corefilers and junctions
* add global or vserver custom settings
* add targeted custom settings for the junctions

This provider requires a controller to be installed that is used to create and manage the Avere vFXT.  The following examples provide details on how to use terraform to deploy the controller:
1. [Install a one core filer Avere vFXT](../../examples/vfxt/1-filer)
2. [Install a three core filer Avere vFXT](../../examples/vfxt/3-filers)
3. [Install a no filer Avere vFXT](../../examples/vfxt/no-filers)

## Build the Terraform Provider binary

Install either a Centos or Ubuntu Virtual Machine

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

2. If not already installed go, install golang:

    ```bash
    wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
    tar xvf go1.13.5.linux-amd64.tar.gz
    sudo chown -R root:root ./go
    sudo mv go /usr/local
    mkdir ~/gopath
    echo "export GOPATH=$HOME/gopath" >> ~/.profile
    echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
    source ~/.profile
    rm go1.13.5.linux-amd64.tar.gz
    ```

3. build the provider code
    ```bash
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    cd src/github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    go build
    mkdir -p ~/.terraform.d/plugins
    cp terraform-provider-avere ~/.terraform.d/plugins
    ```

4. Install the provider `~/.terraform.d/plugins/terraform-provider-avere` to the ~/.terraform.d/plugins directory of your terraform environment.