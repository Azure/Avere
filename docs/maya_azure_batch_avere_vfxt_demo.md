# Video rendering with Maya, Azure Batch, and Avere vFXT for Azure

This 60-minute demo takes you through rendering an animated movie using Maya, Batch, and the Avere vFXT cluster. 

> The source code to produce the template is located [here](../src/mayabatch).

## Prerequisites

1. Install a vFXT cluster according to [Deploy a vFXT cluster](jumpstart_deploy.md), and [configure storage](configure_storage.md).

2. Create a Windows 10 workstation for Avere vFXT with [Windows 10 workstation for Avere vFXT](windows_10_avere_vfxt_mounted_workstation.md).

3. On the cluster controller, mount the vFXT shares. 

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
        172.16.0.12:/msazure	/nfs/node1	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
        172.16.0.13:/msazure	/nfs/node2	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
        172.16.0.14:/msazure	/nfs/node3	nfs auto,rsize=524288,wsize=524288,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
        ```

    3. To mount all shares, type `mount -a` from the cluster controller. 

## Prepare content and infrastructure

This step downloads the frames to render, the client mounting script, and the render task script to the appropriate machines. 

1. Use the Windows 10 workstation or cluster controller to download a Maya scene to the controller's `/mnt/scene` folder.  

   This demo uses the walking skeleton example from https://www.turbosquid.com/3d-models/3d-model-kong-skeleton-1192846.

2. Copy the downloaded unzipped scene to the folder "/demoscene" on the Avere vFXT volume.  

   If you are using the Kong skeleton, you will need to change the hard-coded paths so that it renders correctly. Here are the two methods:

   1. Use the Notepad++ text editor from the Windows workstation to find and replace the following two strings with the empty string:
   
        ```powershell
        G:/EVERYDAY/Kong/Kong/
        G:/EVERYDAY/Kong skeleton/KongSkeleton/
        ```
		
   2. Using sed from the cluster controller: 
   
        ```bash
        cd /nfs/avere1/demoscene
        sed -i "s/G:\/EVERYDAY\/Kong\/Kong\///g" kongSkeleton_walk.ma
        sed -i "s/G:\/EVERYDAY\/Kong skeleton\/KongSkeleton\///g" *.ma
        ```
	
3. Copy the following file, keeping the same name, to the Avere vFXT volume. Store it in a folder named ``bootstrap``:

   ```
   https://github.com/Azure/Avere/blob/master/src/mayabatch/centosbootstrap.sh
   ```
	
4. Copy the following file, keeping the same name, to the Avere vFXT volume. Store it in a folder named ``/src``:

   ```
   https://github.com/Azure/Avere/blob/master/src/mayabatch/render.sh
   ```

## Create an Azure Batch account and a pool

The steps below create an Azure Batch account and a pool.  

> Tip: If you ask for a quota increase on the Batch account, don't delete the account - deleting the account will result in a loss of the quota.  

If you are not familiar with Azure Batch, the following pages cover the concepts of Batch accounts, pools, and jobs: https://docs.microsoft.com/en-us/azure/batch/batch-technical-overview.

1. To create the Batch account, run the following commands in a cloud shell (from http://portal.azure.com or https://shell.azure.com):

   ```bash
   export DstSub="SUBSCRIPTIONID"
   export DstResourceGroupName="avere0807batcha"
   export DstLocation="eastus2"
   export BatchAccountName="avere0807batcha"
   
   az account set --subscription $DstSub
   az group create --name $DstResourceGroupName --location $DstLocation
   
   az batch account create --location $DstLocation --resource-group $DstResourceGroupName --name $BatchAccountName
   
   az batch account login --resource-group $DstResourceGroupName --name $BatchAccountName
   ```

2. Next, you will need to add the Batch CLI extensions to enable pool and job creation.  

   You can safely ignore any errors informing you that the extensions have been added (more information is here: https://docs.microsoft.com/en-us/azure/batch/batch-cli-templates).
   
   ```bash
   # add the cli extensions if they are not already added
   az extension add --name azure-batch-cli-extensions
   ```

3. Now that the account is created, download the pool templates, edit the parameters with the vFXT information and node count, and finally create the pool by running all the commands.  

   The pool template uses the ``bootstrap`` script installed [previously](#prepare-content-and-infrastructure) on the vFXT cluster to mount all the shares.

   ```bash
   # create ~/batch directory
   mkdir -p ~/batch
   cd ~/batch
   
   # download the batch 
   curl -o pool.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/mayabatch/pool.json
   curl -o pool-parameters.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/mayabatch/pool-parameters.json
   vi pool-parameters.json
   
   # login, in case you are not already logged into batch
   az batch account login --resource-group $DstResourceGroupName --name $BatchAccountName
   az batch pool create --template pool.json --parameters pool-parameters.json
   ```

4. Log in to the Azure Batch Explorer on the Windows workstation and you can see the pool starting.

## Production: Run a job to render the demo scene

This step uses Azure Batch to create and run Maya render tasks for each frame of the movie.  The frame creation is output to the Avere vFXT cluster under the ``/images`` path.  

Each task uses the ``render`` script that you downloaded under ``/src`` in the [preparation](#prepare-content-and-infrastructure) step.

1. Even before all the nodes start up in the demo, you can start the job running by issuing the following commands:

   ```bash
   cd ~/batch
   
   # download the batch 
   curl -o job.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/mayabatch/job.json
   curl -o job-parameters.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/mayabatch/job-parameters.json
   vi job-parameters.json
   
   # login, in case you are not already logged into batch
   az batch account login --resource-group $DstResourceGroupName --name $BatchAccountName
   az batch job create --template job.json --parameters job-parameters.json
   ```

2. Use Azure Batch Explorer on the Windows machine to watch the progress of the jobs, and inspect the log output.  On the Windows machine, you should start to see the images (ending in .iff) show in the ``/images`` directory.

## Post-production: Build the movie from the rendered frames

In the previous step, you rendered the scene into many frame files.  In this step you will take these files and build a movie file.

1. RDP to the Windows workstation.

2. Open the VirtualDub application from the desktop shortcut.

3. Choose File > Open and browse to `c:\AvereVFXT\images\job1\images` (or different job name if you chose a different job) and select the file ending in ``0.IFF``.

4. From the File menu, click `Save as AVI…`, and save to the desktop.

5. After the export completes, you can click on the file on the desktop and see your new movie.

   <img src="images/win10_postproduction.png">

