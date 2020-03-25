# Terraform Avere vFXT Provider

This directory contains the code to build a provider for the Avere vFXT for Azure.

The provider has the following features:
* create / destroy the Avere vFXT cluster
* scale-up / scale-down from 3 to 16 nodes
* add or remove corefilers and junctions
* add or remove Azure Blob Storage cloud core filer
* add global or vserver custom settings
* add targeted custom settings for the junctions

## Examples on how to use

This provider requires a controller to be installed that is used to create and manage the Avere vFXT.  The following examples provide details on how to use terraform to deploy the controller:
1. [Install Avere vFXT for Azure](../../examples/vfxt/no-filers)
2. [Install Avere vFXT mounting Azure Blob Storage cloud core filer](../../examples/vfxt/azureblobfiler)
3. [Install Avere vFXT for Azure mounting 1 IaaS NAS filer](../../examples/vfxt/1-filer)
4. [Install Avere vFXT for Azure mounting 3 IaaS NAS filers](../../examples/vfxt/3-filers)

## Build the Terraform Provider binary

The following build instructions work in https://shell.azure.com, Centos, or Ubuntu:

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

2. If not already installed go, install golang:

    ```bash
    wget https://dl.google.com/go/go1.14.linux-amd64.tar.gz
    tar xvf go1.14.linux-amd64.tar.gz
    mkdir ~/gopath
    echo "export GOPATH=$HOME/gopath" >> ~/.profile
    echo "export PATH=\$GOPATH/bin:$HOME/go/bin:$PATH" >> ~/.profile
    echo "export GOROOT=$HOME/go" >> ~/.profile
    source ~/.profile
    rm go1.14.linux-amd64.tar.gz
    ```

3. build the provider code
    ```bash
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    cd src/github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    go mod download
    go mod tidy
    go build
    mkdir -p ~/.terraform.d/plugins
    cp terraform-provider-avere ~/.terraform.d/plugins
    ```

4. Install the provider `~/.terraform.d/plugins/terraform-provider-avere` to the ~/.terraform.d/plugins directory of your terraform environment.