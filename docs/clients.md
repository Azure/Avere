# Virtual Machine Client Implementations that mount the Avere vFXT Edge Filer

This tutorial discusses three virtual machine (VM) implementations to deploy multiple VMs mounted to the Avere vFXT: loose VMs, VM availability sets (VMAS), and VM scale sets (VMSS).

The clients are mounted round robin across the Avere vFXT vServer IP addresses.  The mounting is done by a bootstrap script stored on the vFXT.  Before deploying the clients, the bootstrap script must be installed to the Avere vFXT.  The controller can be used to mount and install the bootstrap script. The bootstrap script can also be modified to install client applications, and examples can be seen for the [vdbench](vdbench.md) and the [data ingestor](data_ingestor.md) tutorials.

Here are the steps to install the bootstrap script from the controller, and then deploy the clients using that bootstrap script.

1. Run the following commands:

```bash
sudo -s
apt-get update
apt-get install nfs-common
mkdir -p /nfs/node0
mkdir -p /nfs/node1
mkdir -p /nfs/node2
chown nobody:nogroup /nfs/node0
chown nobody:nogroup /nfs/node1
chown nobody:nogroup /nfs/node2
```

2. Edit `/etc/fstab` to add the following lines but *using your vFXT node IP addresses*. Add more lines if your cluster has more than three nodes.

```bash
10.0.0.12:/msazure	/nfs/node0	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
10.0.0.13:/msazure	/nfs/node1	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
10.0.0.14:/msazure	/nfs/node2	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
```

3. To mount all shares, type `mount -a` from the cluster controller, and then run the following to download the bootstrap script.

```bash
mkdir -p /nfs/node1/bootstrap
cd /nfs/node1/bootstrap
curl --retry 5 --retry-delay 5 -o /nfs/node1/bootstrap/bootstrap.sh https://raw.githubusercontent.com/Azure/Avere/main/src/client/bootstrap.sh
```

Next choose the client implementation most appropriate to your scenario.  To understand how to maximize boot speed of these VMs, please review [Best Practices for Improving Azure Virtual Machine (VM) Boot Time](azure_vm_provision_best_practices.md).

   | Launch Link | Description |
   | --- | --- |
   | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmain%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank"><img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/></a> | Loose Virtual Machines - use for a small number of clients |
   | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmain%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank"><img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/></a> | Virtual Machine Availability Sets (VMAS) - use to increase deployment performance over loose virtual machines |
   | <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmain%2Fsrc%2Fclient%2Fvmss%2Fazuredeploy.json" target="_blank"><img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/></a> | Virtual Machine Scale Sets (VMSS) - use for large scale virtual machine deployment |
