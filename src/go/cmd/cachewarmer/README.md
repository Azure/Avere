# CacheWarmer - run the cache warmer daemon

The CacheWarmer provides a method for warming an Avere Cache Filer.  This may be use for the HPC Cache or the Avere vFXT for Azure.

The components of the cache warmer are the following:
1. `cachewarmer-jobsubmitter` - submits the jobs for the cachewarmer
2. `cachewarmer-manager` - reads jobs, and produces "warm" jobs for each sub directory
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
    wget https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
    tar xvf go1.11.2.linux-amd64.tar.gz
    sudo chown -R root:root ./go
    sudo mv go /usr/local
    mkdir ~/gopath
    echo "export GOPATH=$HOME/gopath" >> ~/.profile
    echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
    source ~/.profile
    rm go1.11.2.linux-amd64.tar.gz
    ```

2. setup CacheWarmer code
    ```bash
    # checkout CacheWarmer code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/go/...
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
    # login as root
    sudo -s
    # download the bootstrap files
    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o bootstrap.cachewarmer-manager.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-manager.sh
    curl --retry 5 --retry-delay 5 -o bootstrap.cachewarmer-worker.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/bootstrap.cachewarmer-worker.sh

    # copy in the built binaries
    mkdir -p /nfs/node0/bootstrap/cachewarmerbin
    cp $GOPATH/bin/cachewarmer-* /nfs/node0/bootstrap/cachewarmerbin

    # download the rsyslog scripts
    mkdir /nfs/node0/bootstrap/rsyslog
    cd /nfs/node0/bootstrap/rsyslog
    curl --retry 5 --retry-delay 5 -o 35-cachewarmer-manager.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/35-cachewarmer-manager.conf
    curl --retry 5 --retry-delay 5 -o 36-cachewarmer-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/rsyslog/36-cachewarmer-worker.conf
        
    # download the service scripts
    mkdir /nfs/node0/bootstrap/systemd
    cd /nfs/node0/bootstrap/systemd
    curl --retry 5 --retry-delay 5 -o cachewarmer-manager.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-manager.service
    curl --retry 5 --retry-delay 5 -o cachewarmer-worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/cachewarmer/deploymentartifacts/bootstrap/systemd/cachewarmer-worker.service
    ```

### Install the cachewarmer manager on the Controller or Jumpbox

On the controller or jumpbox, execute the following steps

1. Edit and execute the following environment variables:
```bash
export BOOTSTRAP_PATH=/nfs/node0/bootstrap/
export BOOTSTRAP_SCRIPT=bootstrap.cachewarmer-manager.sh
export JOB_MOUNT_ADDRESS=10.0.1.11
export JOB_EXPORT_PATH=/nfs1data
export JOB_BASE_PATH=/
```
2. Run the following script:
```bash
/nfs/node0/bootstrap/bootstrap.cachewarmer-manager.sh
```

### Install the cachewarmer worker on the Controller or Jumpbox

On the controller or jumpbox, execute the following steps

1. Edit and execute the following environment variables:
```bash
export BOOTSTRAP_PATH=/nfs/node0/bootstrap/
export BOOTSTRAP_SCRIPT=bootstrap.cachewarmer-worker.sh
export JOB_MOUNT_ADDRESS=10.0.1.11
export JOB_EXPORT_PATH=/nfs1data
export JOB_BASE_PATH=/
```
2. Run the following script:
```bash
/nfs/node0/bootstrap/bootstrap.cachewarmer-worker.sh
```

## Running the CacheWarmer

To submit a job, run a command similar to the following command, where the warm target variables are the Avere junction to warm:

```bash
sudo /usr/local/bin/cachewarmer-jobsubmitter -enableDebugging -jobBasePath "/" -jobExportPath "/nfs1data" -jobMountAddress "10.0.1.11" -warmTargetExportPath "/nfs1data" -warmTargetMountAddresses "10.0.1.11,10.0.1.12,10.0.1.13" -warmTargetPath "/island"
```
