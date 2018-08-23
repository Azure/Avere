# Configure Storage

There are two steps to set up a back-end storage system for your vFXT cluster. 
1. [Create a core filer](#create-a-core-filer), which connects your vFXT cluster to an existing storage system.
1. [Create a namespace junction](#create-a-junction), which provides a path for clients to mount.

## Create a core filer
"Core filer" is a vFXT term for a storage system. It is most often a NAS like NetApp or Isilon. More information about core filers can be found [here](http://library.averesystems.com/ops_guide/4_7/settings_overview.html#managing-core-filers).

If you want to connect an existing hardware storage system or cloud container to your vFXT cluster, follow the instructions below. 

If you need to create a new Azure storage container to serve as your back-end storage, follow the instructions in [Creating an Azure storage account](create_azure_storage.md) before using these instructions to add it to the cluster. 

- From the Avere Control Panel, click the Settings tab at the top.
- Click “Manage Core Filers” on the left. 
- Click “Create.”

<img src="images/22addcorefiler1b.png">

- For a NAS core filer: 
  * Name your core filer.
  * Provide a fully qualified domain name (FQDN) if available. Otherwise, provide an IP address or hostname that resolves to your core filer.
  * Choose your filer class from the list. If unsure, choose “Other.”
  * Click **Next** and choose a cache policy. 
  * Click **Add Filer**.
  * Refer to [Adding a new NAS core filer](http://library.averesystems.com/ops_guide/4_7/new_core_filer_nas.html) for more detailed information.
  
- For a cloud core filer: 
  * Name your core filer and click **Next**.
  * Accept the default cache policy and continue to the third page. 
  * In **Service type**, choose **Azure storage**. 
  * If you have already defined a storage credential for your Azure subsccription, choose it from the list. If not, choose **Add a credential set**, name the new credential, and paste a key from the storage container into the **Access key** field. Leave the  **Private key** field blank.    
    Read [Copying an access key](#copying-an-azure-storage-access-key), below, to learn where to find the credential.
  * On the fourth page, enter the name of the container in **Bucket name**. 
  * Click **Add Filer**.
  * Refer to [Adding a new cloud core filer](<http://library.averesystems.com/ops_guide/4_7/new_core_filer_cloud.html>) for more detailed information. 
- Click Next.

The page will refresh, or you can refresh the page to display your new core filer.

## Create a junction
A junction is a path that you create for clients. Clients mount the path in order to arrive at the destination you choose. For example, you could create `/avere/files` to map to your NetApp core filer, `/vol0/data` export, and the `/project/resources` subdirectory.
More information about junctions can be found [here](http://library.averesystems.com/ops_guide/4_7/gui_namespace.html).
- Click “Namespace” in the upper left.
- Provide a namespace path beginning with / (forward slash) like /avere/data.
- Choose your core filer.
- Choose the export.
- Click “Next.”

<img src="images/24addjunction.png">

The junction will appear after a few seconds. Create additional junctions as needed.



### Copying an Azure storage access key

Follow these instructions to find a key to paste into your cloud core filer definition.

1. In the Azure portal, browse to the storage account resource that holds the core filer container. 
2. Under **Settings**, click **Access keys**. 
3. Copy one of the keys. 

<img src="images/copy_storage_key.png">
