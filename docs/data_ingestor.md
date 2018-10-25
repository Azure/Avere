# Data Ingestor - Parallel data ingest 

This implements a data ingestor required for efficient efficient and parallel data ingestion to the Avere vFXT as shown in the following diagram:

<p >
<img src="images/parallel_ingestion.png">
</p>

The data ingestor has tools such as the ``msrsync`` utility and the ``parallelcp`` script.    To install a data ingestor VM containing all of these parallel data ingestion tools, we will have the client VM pull and run the data ingestor install script from the Avere vFXT mount using one of the [generic virtual machine clients](clients.md).  Before deploying the client VM, first setup the Avere vFXT with the install file:

1. If you have not already done so, ssh to the controller, and mount to the Avere vFXT:

    1. Run the following commands:
        ```bash
        sudo -s
        apt-get update
        apt-get install nfs-common
        mkdir -p /nfs/node0
        chown nobody:nogroup /nfs/node0
        ```

    2. Edit `/etc/fstab` to add the following lines but *using your vFXT node IP addresses*. Add more lines if your cluster has more than three nodes.
        ```bash
        10.0.0.12:/msazure	/nfs/node0	nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0
        ```

    3. To mount all shares, type `mount -a`

2. On the controller, download the dataingestor bootstrap script:
    ```bash
    mkdir -p /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.dataingestor.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/dataingestor/bootstrap.dataingestor.sh
    ```

3. From your controller, verify your dataingestor setup by running the following verify script.  If the script shows success, you are ready to deploy.  Otherwise you will need to fix each error listed.

    ```bash
    curl -o- https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/dataingestor/dataingestorVerify.sh | bash
    ```

4. Deploy the clients by clicking the "Deploy to Azure" button below, but set the following settings:
  * specify `/bootstrap/bootstrap.dataingestor.sh` for the bootstrap script

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

Click the following links to learn more about the data ingestor tools:

1. msrsync -  available from GitHub at https://github.com/jbd/msrsync

2. parallelcp - mentioned in the [ingestion guide](getting_data_onto_vfxt.md#using-the-parallel-copy-script).

To learn more about parallel ingestion, please refer to the [ingestion guide](getting_data_onto_vfxt.md#using-the-parallel-copy-script).
