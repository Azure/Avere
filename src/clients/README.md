# Virtual Machine Client Implementations that mount Avere vFXT

This folder includes two Virtual Machine implementations to deploy multiple VMs mounted to the Avere vFXT: Virtual Machine Availability Sets (VMAS), and Virtual Machine Scale Sets (VMSS).

In both examples, the clients are mounted roundrobin across the Avere vFXT vServer IP addresses.  A bootstrap script stored on the vFXT does this round robin mounting, and provides a mechanism to deploy software on the machine.

For the default case, mount the controller, and create the bootstrap directory and download the bootstrap script for the clients.  On the cluster controller, mount the vFXT shares. 

    1. Run the following commands:

       ```bash
       sudo -s
       apt-get update
       apt-get install nfs-common
       mkdir -p /nfs/node1
       mkdir -p /nfs/node2
       mkdir -p /nfs/node3
       chown nobody:nogroup /nfs/node1
       chown nobody:nogroup /nfs/node2
       chown nobody:nogroup /nfs/node3
       ```

    2. Edit `/etc/fstab` to add the following lines but *using your vFXT node IP addresses*. Add more lines if your cluster has more than three nodes. 
        ```bash
        10.0.0.12:/msazure	/nfs/node1	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
        10.0.0.13:/msazure	/nfs/node2	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
        10.0.0.14:/msazure	/nfs/node3	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
        ```

    3. To mount all shares, type `mount -a` from the cluster controller, and then run the following to download the bootstrap script.

        ```bash
        mkdir -p /nfs/node1/bootstrap
        cd /nfs/node1/bootstrap
        curl --retry 5 --retry-delay 5 -o /nfs/node1/bootstrap/bootstrap.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clients/bootstrap.sh
        ```

# Virtual Machine Availability Sets (VMAS)

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclients%2Fvmas%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

# Virtual Machine Scale Sets (VMSS)

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclients%2Fvmss%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>