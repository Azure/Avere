# Vdbench - measuring vFXT performance

This is a basic setup to generate small and medium sized workloads to test the vFXT memory and disk subsystems.  The suggested configuration is 12 x Standard_D2s_v3 clients for each group of 3 vFXT nodes.

[vdbench download and documentation](https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html)

## Deployment

These deployment instructions describe the installation of all components required to run Vdbench:

1. Deploy an Avere vFXT as described in [Deploy](jumpstart_deploy.md).

2. If you have not already done so, ssh to the controller, and mount to the Avere vFXT:

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

    3. To mount all shares, type `mount -a`

4. On the controller, download the vdbench bootstrap script:
    ```bash
    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.vdbench.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/bootstrap.vdbench.sh
    ```

5. Download the latest vdbench from https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html, and scp to the `/bootstrap` directory.  To download you will need to create an account with Oracle and accept the license.

6. From your controller, verify your vdbench setup by running the following script.  If the script shows success, you are ready to deploy.  Otherwise you will need to fix each error listed.

    ```bash
    curl -o- https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/vdbenchVerify.sh | bash
    ```

7. Deploy the clients by clicking the "Deploy to Azure" button below, but set the following settings:
  * SSH key is required for vdbench
  * specify `/bootstrap/bootstrap.vdbench.sh` for the bootstrap script

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

## Using vdbench

1. After deployment is complete, find the IP of one of the VDBench clients from the [portal](https://portal.azure.com) or https://resources.azure.com, and login from the controller and run the following commands to set your private SSH secret:

   ```bash
   touch ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   vi ~/.ssh/id_rsa
   ```
	
2. During installation, `copy_dirsa.sh` was installed to `~/.` on the vdbench client machine, to enable easy copying of your private key to all vdbench clients.  Run `~/copy_idrsa.sh` to copy your private key to all vdbench clients, and to add all clients to the "known hosts" list. (**Note** if your ssh key requires a passphrase, some extra steps are needed to make this work. Consider creating a key that does not require a passphrase for ease of use.)


### Memory test 

1. To run the memory test (approximately 20 minutes), issue the following command:

   ```bash
   cd
   ./run_vdbench.sh inmem.conf uniquestring1
   ```

2. Log in to the Avere vFXT cluster GUI (Avere Control Panel - instructions [here](access_cluster.md)) to watch the performance metrics. You will see a similar performance chart to the following:

   <img src="images/vdbench_inmem.png">

### On-disk test

1. To run the on-disk test (approximately 40 minutes) issue the following command:

   ```bash
   cd
   ./run_vdbench.sh ondisk.conf uniquestring2
   ```

2. Log in to the Avere Control Panel ([instructions](access_cluster.md)) to watch the performance metrics. You will see a performance chart similar to the following one:

   <img src="images/vdbench_ondisk.png">