# VMScaler for maintaining a VM farm of low priority nodes

This VMScaler maintains a VM farm of low priority nodes.  It does this by managing the VMSS capacity within a Resource Group, including quickly restoring evicted nodes.

The features are as follows:
 1. Allows you to set the number of nodes to run within a resource group by setting the 'TOTAL_NODES' tag on that group.
 1.	Allows you to set the density of VMSS for the fastest boot times per article: https://github.com/Azure/Avere/blob/master/docs/clients.md
 1.	Even if nodes are evicted, ensures the node count stays at “TOTAL_NODES” set on the resource group
 1.	Self-running VM locked down to VMSS actions only of the resource group
 1.	“Seals” VMSS instances that no longer resize larger
 1.	Creates new VMSS instances to make up for sealed instances
 1.	A node deletes itself by queuing a delete instance message.  The vmscaler uses this message to decrement “TOTAL_NODES” and delete the instance.

The vmscaler uses Azure Storage Queue for deletion of instances.  This enables a node to self-destruct, or a render manager to choose which nodes to delete.

## Installation Instructions for Linux

 1. If not already installed go, install golang:

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

 2. setup vmscaler code
```bash
# checkout vmscaler code, all dependencies and build the binaries
cd $GOPATH
go get -v github.com/Azure/Avere/src/go/...
```

## Mount NFS and build up a bootstrap directory

These deployment instructions describe the installation of all components required to run Vdbench:

1. Mount the nfs share.  For this example, we are mounding to /nfs/node0

2. On the controller, setup all vmscaler binaries (using instructions to build above), bootstrap scripts, and service configuration files:
    ```bash
    # download the bootstrap files
    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o bootstrap.vmscaler.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/bootstrap.vmscaler.sh
    
    # copy in the built binaries
    mkdir -p /nfs/node0/bootstrap/vmscalerbin
    cp $GOPATH/bin/vmscaler /nfs/node0/bootstrap/vmscalerbin

    # download the rsyslog scripts
    mkdir /nfs/node0/bootstrap/rsyslog
    cd /nfs/node0/bootstrap/rsyslog
    curl --retry 5 --retry-delay 5 -o 34-vmscaler.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/rsyslog/34-vmscaler.conf
        

    # download the service scripts
    mkdir /nfs/node0/bootstrap/systemd
    cd /nfs/node0/bootstrap/systemd
    curl --retry 5 --retry-delay 5 -o vmscaler.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/deploymentartifacts/bootstrap/systemd/vmscaler.service
    ```

6. Deploy the eda simulator cluster by clicking the "Deploy to Azure" button below::
    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fgo%2Fcmd%2Fvmscaler%2Fdeploymentartifacts%2Ftemplate%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

## To Run

To look at logs on the vmscaler, tail the logs under /var/log/vmscaler/ directory.
