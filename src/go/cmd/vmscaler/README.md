# VMScaler - maintain a VM farm of low priority VMSS nodes

The VMScaler maintains a VM farm of low priority Virtual Machine Scaleset (VMSS) nodes.  It does this by managing the total node capacity of all running VMSS instances within a resource group.  The primary use case is cloud burstable render farms by VFX rendering houses.

The features include:
 1.	Restore evicted low-priority nodes and ensure the node count stays at the value set by the resource group tag `TOTAL_NODES`.
 1.	"Seals" VMSS instances that no longer increase in size.
 1.	Creates new VMSS instances to make up for sealed instances.
 1.	Automation scripts that can be used by render managers for automated scale-up / scale-down of capacity.
 1.	Self-running VM locked down by RBAC to VMSS actions only of the resource group.
 1. The VMScaler uses managed identity and has scoped access only the resource group, VNET, and custom image.
 1. Ability to set the density of VMSS for the fastest boot times according to the report [Best Practices for Improving Azure Virtual Machine (VM) Boot Time](../../../../docs/azure_vm_provision_best_practices.md).

A separate VMScaler / Resource Group pair is created per VM SKU.

## Installation Instructions for Linux

These instructions work on Centos 7 (systemd) and Ubuntu 18.04.  This creates a manager node that runs the VMScaler application as a service.  Here are the general steps:
 1. Build the Golang binary
 1. Install the binary and service files to an NFS share
 1. Deploy the VMScaler VM

Before deploying ensure the following pre-equisites exists:
  1. **Virtual Network** - A virtual network exists and is already setup.  This is true for almost all cloud based VFX rendering houses.  If you are testing, use the portal to setup a virtual network before deployment.
  1. **Subnets** - a subnet large enough to support the VMSS nodes has been configured on the virtual network.
  1. **No public IP** - A cloud based VFX rendering network is locked down and does not allow public IPs to be added.  If you are testing, use the portal to create a public IP and associate with the NIC after installing.
  1. **NFS Filer** - An NFS filer exists to store the VMScaler binary and bootstrap files.  If you are testing, use the portal to add an NFS endpoint like the Avere vFXT or Azure Netapp Files.
  1. **Custom Image** - A custom image has been created for use with deployment.  Most cloud based VFX rendering houses will already have a CentOS7 based custom image.

### Build the VMScaler binary

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

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

2. setup VMScaler code
    ```bash
    # checkout VMScaler code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/go/...
    ```

### Mount NFS and build a bootstrap directory

These deployment instructions describe the installation of all components required to run Vdbench:

1. Mount the nfs share.  For this example, we are mounding to /nfs/node0.  Here are the sample commands for CentOS 7 or Ubuntu:

    ```bash
    # for CentOS7
    sudo yum -y install nfs-utils 
    sudo mkdir -p /nfs/node0
    sudo sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' 10.0.16.12:/msazure /nfs/node0
    
    # for Ubuntu
    sudo apt-get install -y nfs-common
    sudo mkdir -p /nfs/node0
    sudo sudo mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' 10.0.16.12:/msazure /nfs/node0
    ```

2. On the controller, setup all VMScaler binaries (using instructions to build above), bootstrap scripts, and service configuration files:
    ```bash
    # download the bootstrap files
    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o bootstrap.vmscaler.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/bootstrap.vmscaler.sh

    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o delete_vmss_instance.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/delete_vmss_instance.sh

    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o set_capacity.imds.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/set_capacity.imds.sh

    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o set_capacity.service_principal.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/set_capacity.service_principal.sh

    # copy in the built binaries
    mkdir -p /nfs/node0/bootstrap/vmscalerbin
    cp $GOPATH/bin/vmscaler /nfs/node0/bootstrap/vmscalerbin

    # download the rsyslog scripts
    mkdir /nfs/node0/bootstrap/rsyslog
    cd /nfs/node0/bootstrap/rsyslog
    curl --retry 5 --retry-delay 5 -o 34-vmscaler.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/rsyslog/34-vmscaler.conf
        
    # download the service scripts
    mkdir /nfs/node0/bootstrap/systemd
    cd /nfs/node0/bootstrap/systemd
    curl --retry 5 --retry-delay 5 -o vmscaler.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/vmscaler/deploymentartifacts/bootstrap/systemd/vmscaler.service
    ```
### Deploy the VM Manager Node

Deploy the VMScaler cluster by clicking the "Deploy to Azure" button below.  Ensure you deploy once VMscaler per resource group:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fgo%2Fcmd%2Fvmscaler%2Fdeploymentartifacts%2Ftemplate%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Here is a summary of the input parameters:

  * **storageAccountName** - The unique name of the storage account to be created for queue.
  * **uniquename** - The unique name used for resource names associated with the virtual machine.
  * **rbacRoleAssignmentUniqueId** - The Azure role assignment unique id.  Use a guid from https://www.guidgenerator.com.  If blank, vmname is used. 
  * **adminUsername** - The admin username for the virtual machine node and vmss clients.
  * **adminPassword** - The vm password to use for the virtual machine.
  * **virtualNetworkResourceGroup** - The resource group name for the VNET containing the Avere vFXT.
  * **virtualNetworkName** - The name used for the virtual network for the VNET containing the Avere vFXT.
  * **virtualNetworkSubnetName** - The unique name used for the virtual network subnet for the VNET containing the Avere vFXT.
  * **bootstrapNFSIP** - The NFS address used for mounting the bootstrap directory (ex. '10.0.0.12').
  * **nfsExportPath** - The path exported from the NFS server that will be mounted. (ex. '/msazure').
  * **vmscalerBootstrapScriptPath** - The bootstrap script path that configures the vmscaler as a service (ex. '/bootstrap/bootstrap.vmscaler.sh') 
  * **vmscalerVmSize** - The SKU size of worker vms to deploy.
  * **vmssImageId** - The custom image id to be used for the VMSS instances.
  * **vmssSKU** - The sku to use for the VMSS instances.
  * **vmsPerVMSS** - The number of nodes per VMSS, vary this number to vary performance.  This is based on the report [Best Practices for Improving Azure Virtual Machine (VM) Boot Time](../../../../docs/azure_vm_provision_best_practices.md).

After deploying, the deployment output variables show the following:
 * **ssh_string** - the username and ip address combined as an SSH address.  This will be a private IP address, so you will need to be on the same virtual network.
 * **resource_group** - the resource group where the VM was deployed.
 * **location** - the location where the VM was deployed

## RBAC

The deployed VM is configured with managed identity and has the following scoped RBAC access:

   | Name | Role Required | Scope | Description |
   | --- | --- | --- | --- |
   | **VMScaler Access** | [Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) | the VMScaler resource group | the VMScaler needs contributor to create / manage VMSS, and also update tags on the resource group. |
   | **VNET Subnet Join Access** | [Avere Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) | the VNET resource group | the VMScaler needs access to join into VNET subnets. |
   | **VMImage Read Access** | [Avere Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) | the VM Image resource group | the VMScaler needs contributor to read images (only the Avere Contributor has the ability to read images.). |

## Running the VMScaler

The VMScaler automatically runs as a systemd service.  The logs for the service are under /var/log/vmscaler/ directory.  The process is self-restarting.

The number of VMs deployed is controlled by setting the `TOTAL_NODES` on the resource group.  An empty resource group starts out with 0 nodes.

## Automating Scale-up and Scale-down of VMSS Instances

After the VMScaler deploys, the following files are written to the user directory to automate scale-up and scale-down:

| Name | Role Required |
| --- | --- |
| `set_capacity.imds.sh` | Set the capacity of the resource group lower or higher.  This uses managed identity and can only be run from the VMScaler VM. |
| `set_capacity.serviceprincipal.sh` | Set the capacity of the resource group lower or higher using a service principal.  To create the service principal you can use these [instructions](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest).  The service principal can be scoped to the resource group, but needs at least *Contributor* role to write to the resource group.|
| `delete_vmss_instance.sh` | This is run from any VMSS instance in the VM farm.  This has auth specific to the resource group / storage account, so cannot be used for other resource group / vmscaler deployments. | 
 
To scale-up, use either of the set capacity scripts to set the `TOTAL_NODES` capacity higher on the resource group.  The VMScaler will automatically scale-up the instances.  If the value is set lower than the existing capacity, the VMScaler will lazily allow evictions to get the VM farm to lower capacity.

One method of actively scaling down the VMSS nodes is to call the delete vmss instance script when the node has gone idle.  This will cause the VMScaler to delete the instance and decrement the capacity by 1.  The VMScaler will automatically scale down the instances all the way to 0.