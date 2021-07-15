# CacheWarmer - run the cache warmer daemon

The CacheWarmer provides a method for warming a cache filer.  This may be use for the [Azure HPC Cache](https://azure.microsoft.com/services/hpc-cache/) or the [Avere vFXT for Azure](https://docs.microsoft.com/en-us/azure/avere-vfxt/).  An example of how to deploy this is described in either the [Terraform CacheWarmer for Azure HPC Cache](../../../terraform/examples/HPC%20Cache/cachewarmer) or the [Terraform CacheWarmer for Avere vFXT for Azure](../../../terraform/examples/vfxt/cachewarmer) examples.

The components of the cache warmer are the following:
1. `cachewarmer-jobsubmitter` - submits the jobs for the cachewarmer.  This can be blocking or noblocking on the completion of the warming job.
2. `cachewarmer-manager` - reads jobs from job files submitted to the '.cachewarmjob' directory, and produces "warm" jobs for each sub directory.
3. `cachewarmer-worker` - reads files in parallel as specified from the cachewarmer-worker jobs.

## Installation Instructions for Linux

These instructions work on Centos 7 (systemd) and Ubuntu 18.04.  This can be installed on the controller or the jumpbox.  Here are the general steps:
 1. Build the Golang binary
 1. Install the binary and service files to an NFS share
 
### Build the CacheWarmer binaries

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

2. If not already installed go, install golang:

    ```bash
    GO_DL_FILE=go1.16.6.linux-amd64.tar.gz
    wget --tries=12 --wait=5 https://dl.google.com/go/$GO_DL_FILE
    sudo tar -C /usr/local -xzf $GO_DL_FILE
    rm -f $GO_DL_FILE
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
    source ~/.profile
    ```

2. setup CacheWarmer code
    ```bash
    # checkout and build CacheWarmer
    cd
    RELEASE_DIR=~/release
    mkdir -p $RELEASE_DIR
    git clone https://github.com/Azure/Avere.git
    # build the cache warmer
    cd $AZURE_HOME_DIR/Avere/src/go/cmd/cachewarmer/cachewarmer-jobsubmitter
    go build
    mv cachewarmer-jobsubmitter $RELEASE_DIR/.
    cd $AZURE_HOME_DIR/Avere/src/go/cmd/cachewarmer/cachewarmer-manager
    go build
    mv cachewarmer-manager $RELEASE_DIR/.
    cd $AZURE_HOME_DIR/Avere/src/go/cmd/cachewarmer/cachewarmer-worker
    go build
    mv cachewarmer-worker $RELEASE_DIR/.
    ```

### Mount NFS and build a bootstrap directory

These deployment instructions describe the installation of all components required to run the CacheWarmer:

1. Mount the nfs share.  For this example, we are mounding to /nfs/node0.  Here are the sample commands for CentOS 7 or Ubuntu, and update with your configuration:

    ```bash
    # for CentOS7
    sudo yum -y install nfs-utils 
    sudo mkdir -p /nfs/node0
    sudo sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' 10.0.1.11:/nfs1data /nfs/node0
    
    # for Ubuntu
    sudo apt-get install -y nfs-common
    sudo mkdir -p /nfs/node0
    sudo sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' 10.0.1.11:/nfs1data /nfs/node0
    ```

2. On the controller, setup all CacheWarmer binaries (using instructions to build above), bootstrap scripts, and service configuration files:
    ```bash
    # copy in the built binaries
    sudo mkdir -p /nfs/node0/bootstrap/cachewarmerbin
    sudo cp $GOPATH/bin/cachewarmer-* /nfs/node0/bootstrap/cachewarmerbin

    # login as root for the rest of the install
    sudo -s
    # download the bootstrap files
    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o bootstrap.cachewarmer-manager.sh https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh
    curl --retry 5 --retry-delay 5 -o bootstrap.cachewarmer-worker.sh https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh

    # download the rsyslog scripts
    mkdir /nfs/node0/bootstrap/rsyslog
    cd /nfs/node0/bootstrap/rsyslog
    curl --retry 5 --retry-delay 5 -o 35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf
    curl --retry 5 --retry-delay 5 -o 36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf
        
    # download the service scripts
    mkdir /nfs/node0/bootstrap/systemd
    cd /nfs/node0/bootstrap/systemd
    curl --retry 5 --retry-delay 5 -o cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service
    curl --retry 5 --retry-delay 5 -o cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service
    ```

### Install the cachewarmer manager on the Controller or Jumpbox

On the controller or jumpbox, execute the following steps

1. Edit and execute the following environment variables:
```bash
export BOOTSTRAP_PATH=/nfs/node0

export STORAGE_ACCOUNT=
export STORAGE_KEY=''
export QUEUE_PREFIX=

export BOOTSTRAP_EXPORT_PATH=/nfs1data
export BOOTSTRAP_MOUNT_ADDRESS=10.0.1.11
export BOOTSTRAP_SCRIPT=/bootstrap/bootstrap.cachewarmer-manager.sh
export VMSS_USERNAME=azureuser
# an ssh key or password may be specified
export VMSS_SSHPUBLICKEY='ssh-rsa AAAAB3Nz...UcyupgH'
export VMSS_PASSWORD=
# you may leave the subnet blank
export VMSS_SUBNET=
```

2. Run the following script:
```bash
bash /nfs/node0/bootstrap/bootstrap.cachewarmer-manager.sh
```

### Install the cachewarmer worker on the Controller or Jumpbox

On the controller or jumpbox, execute the following steps

1. Edit and execute the following environment variables:
```bash
export BOOTSTRAP_PATH=/nfs/node0/bootstrap/
export BOOTSTRAP_SCRIPT=bootstrap.cachewarmer-worker.sh
export STORAGE_ACCOUNT=
export STORAGE_KEY=''
export QUEUE_PREFIX=
```
2. Run the following script:
```bash
bash /nfs/node0/bootstrap/bootstrap.cachewarmer-worker.sh
```

## Running the CacheWarmer

To submit a job, run a command similar to the following command, where the warm target variables are the Avere junction to warm:

```bash
sudo /usr/local/bin/cachewarmer-jobsubmitter -enableDebugging -storageAccountName "STORAGEACCOUNTREPLACE" -storageKey "STORAGEKEYREPLACE" -queueNamePrefix "QUEUEPREFIXREPLACE" -warmTargetExportPath "/nfs1data" -warmTargetMountAddresses "10.0.1.11,10.0.1.12,10.0.1.13" -warmTargetPath "/island"
```
