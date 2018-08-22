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
- Name your core filer.
- For a NAS core filer: 
  * Provide a fully qualified domain name (FQDN) if available. Otherwise, provide an IP address or hostname that resolves to your core filer.
  * Choose your filer class from the list. If unsure, choose “Other.”
- For a cloud core filer, follow the instructions in [Adding a new cloud core filer](<http://library.averesystems.com/ops_guide/4_7/new_core_filer_cloud.html>) to supply a credential and the container name. 
- Click Next.

<img src="images/22addcorefiler1b.png">

- Choose a cache policy.
- Click “Add Filer.”
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
