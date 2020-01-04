# Checkpoint Simulator - test the speed of a POSIX FileSystem for checkpointing

## Installation Instructions for Linux

These instructions work on Centos 7 (systemd) and Ubuntu 18.04.  This creates a manager node that runs the VMScaler application as a service.  Here are the general steps:
 1. Build the Golang binary
 1. Install the binary and service files to an NFS share
 1. Deploy the VMScaler VM

### Build the VMScaler binary

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

1. If not already installed go, install golang:

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

2. setup Checkpoint Simulator code
    ```bash
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/go/...
    ```

