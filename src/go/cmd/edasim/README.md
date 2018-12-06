# EDA Simulator to test Filer Performance

This EDA Simulator helps test filer performance.  The simulator has 4 components:
 1. **jobsubmitter** - the task that submits job config files for processing
 1. **orchestrator** - the task the reads the job config files and writes workstart files, and submits work to workers for processing.  This also receives completed jobs from workers, writes a job complete file, and submits a job for upload.
 1. **worker** - the task that takes a workitem, reads the start files, and writes the complete files and or error file depending on error probability. 
 1. **uploader** - this task receives upload tasks for each completed job, and reads all job config files and job work files.
 
The job uses Azure Storage Queue for work management, and uses event hub for measuring file statistics.  The goal of the EDA simulator is to test with various filers to understand the filer performance characteristics.  There is a tool named `statscollector` that will collect and summarize the performance runs from event hub.

The four components above implement the following message sequence chart:

![Message sequence chart for the job dispatch](../../../../docs/images/edasim/msc.png)

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

 2. setup edasim code
```bash
# apply fix for storage queue, remove following lines once fix #9 is committed
cd $GOPATH
go get -v github.com/Azure/azure-storage-queue-go/...
cd $GOPATH/src/github.com/Azure/azure-storage-queue-go
git remote add anhowe https://github.com/anhowe/azure-storage-queue-go.git
git fetch anhowe
git cherry-pick 88364b1a71e18053edd3af5c0c71b53bb8585feb
# get the edasim
cd $GOPATH
go get -v github.com/azure/avere/src/go/...
```

## Storage Preparation

 1. use the portal or cloud shell to create you storage account
 1. create the following queues
     1. jobcomplete
     1. jobprocess
     1. jobready
     1. uploader
 1. use the portal or cloud shell to get the storage account key and set the following environment variables
```bash
export AZURE_STORAGE_ACCOUNT=YOUR_STORAGE_ACCOUNT
export AZURE_STORAGE_ACCOUNT_KEY=YOUR_STORAGE_ACCOUNT_KEY
```

## Event Hub Preparation

 1. use the portal or cloud shell to create an "Event Hubs Namespace" Resource with Pricing Tier "Standard" resource in the same region as the vFXT.  For this example, we created `edasimeventhub`
 1. once created, browse to the "Event Hubs Namespace" in the portal and click "+Event Hub" to add an event hub keeping the defaults of 2 partition counts and 1 day message retention.  For this example, we created event hub `edasim`
 1. once created, browse to "Shared Access Policies", click on "RootManageSharedAccessKey" and copy the primary key
 1. next you will need to set your environment variables with everything you just created:

```bash
export AZURE_EVENTHUB_SENDERKEYNAME="RootManageSharedAccessKey"
export AZURE_EVENTHUB_SENDERKEY="PASTE_SENDER_KEY_HERE"
export AZURE_EVENTHUB_NAMESPACENAME="edasimeventhub"
export AZURE_EVENTHUB_HUBNAME="edasim"
```

## Build Environment String

Using the storage and event hub values above, build a one line string to be used later in deployment:

AZURE_STORAGE_ACCOUNT=YOUR_STORAGE_ACCOUNT AZURE_STORAGE_ACCOUNT_KEY="YOUR_STORAGE_ACCOUNT_KEY" AZURE_EVENTHUB_SENDERKEYNAME="RootManageSharedAccessKey" AZURE_EVENTHUB_SENDERKEY="PASTE_SENDER_KEY_HERE" AZURE_EVENTHUB_NAMESPACENAME="edasimeventhub" AZURE_EVENTHUB_HUBNAME="edasim"

## Deployment of Avere vFXT

These deployment instructions describe the installation of all components required to run Vdbench:

1. Deploy an Avere vFXT as described in [the Avere vFXT documentation](https://aka.ms/averedocs).

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

4. On the controller, setup all edasim binaries (using instructions to build above), bootstrap scripts, and service configuration files:
    ```bash
    # download the bootstrap files
    mkdir /nfs/node0/bootstrap
    cd /nfs/node0/bootstrap
    curl --retry 5 --retry-delay 5 -o bootstrap.jobsubmitter.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/bootstrap.jobsubmitter.sh
    curl --retry 5 --retry-delay 5 -o bootstrap.orchestrator.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/bootstrap.orchestrator.sh
    curl --retry 5 --retry-delay 5 -o bootstrap.onpremjobuploader.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/bootstrap.onpremjobuploader.sh
    curl --retry 5 --retry-delay 5 -o bootstrap.worker.sh https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/bootstrap.worker.sh

    # copy in the built binaries
    mkdir /nfs/node0/bootstrap/edasim
    cp $GOPATH/bin/* /nfs/node0/bootstrap/edasim

    # download the rsyslog scripts
    mkdir /nfs/node0/bootstrap/rsyslog
    cd /nfs/node0/bootstrap/rsyslog
    curl --retry 5 --retry-delay 5 -o 30-orchestrator.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/rsyslog/30-orchestrator.conf
    curl --retry 5 --retry-delay 5 -o 31-worker.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/rsyslog/31-worker.conf
    curl --retry 5 --retry-delay 5 -o 32-onpremjobuploader.conf https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/rsyslog/32-onpremjobuploader.conf

    # download the service scripts
    mkdir /nfs/node0/bootstrap/systemd
    cd /nfs/node0/bootstrap/systemd
    curl --retry 5 --retry-delay 5 -o onpremjobuploader.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/systemd/onpremjobuploader.service
    curl --retry 5 --retry-delay 5 -o orchestrator.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/systemd/orchestrator.service
    curl --retry 5 --retry-delay 5 -o worker.service https://raw.githubusercontent.com/Azure/Avere/master/src/go/cmd/edasim/bootstrap/systemd/worker.service
    ```

6. Deploy one jobsubmitter client by clicking the "Deploy to Azure" button below, but set the following settings.  This creates a machine with the script `job_submitter.sh` and `stats_collector.sh` in the root.  These are the two manual parts of the run where the job batch and statscollector collects and summarizes the perf runs from each batch run.
  * for `appEnvironmentVariables` use the one line environment variable string you created above
  * specify `/bootstrap/bootstrap.jobsubmitter.sh` for the job submitter.

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

7. Deploy the orchestrator on 1-4 machines by clicking the "Deploy to Azure" button below, but set the following settings.  This creates a running orchestrator.
  * for `appEnvironmentVariables` use the one line environment variable string you created above
  * specify `/bootstrap/bootstrap.orchestrator.sh`.

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

8. Deploy the worker on 6-12 machines by clicking the "Deploy to Azure" button below, but set the following settings.  This creates a running workers.
  * for `appEnvironmentVariables` use the one line environment variable string you created above
  * specify `/bootstrap/bootstrap.worker.sh`.

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

9. Deploy the uploader on 1-4 machines by clicking the "Deploy to Azure" button below, but set the following settings.  This creates a running workers.
  * for `appEnvironmentVariables` use the one line environment variable string you created above
  * specify `/bootstrap/bootstrap.onpremjobuploader.sh`.

    <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAvere%2Fmaster%2Fsrc%2Fclient%2Fvmas%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
    </a>

## To Run

Log onto the job submitter machine, and adjust and use the `job_submitter.sh` script to submit batches of varying sizes.  After the batch is complete run the `stats_collector.sh` script to collect and summarize the stats.

To look at logs on the orchestrator, worker, or edasim machines, tail the logs under /var/log/edasim/ directory.
