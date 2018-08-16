# Configure Storage
There are three steps to configuring storage.
1. [Create a core filer](#create-a-core-filer), which connects your vFXT to your local NAS.
1. [Create a vserver](#create-a-vserver), which provides IP addresses for clients to mount.
1. [Create a junction](#create-a-junction), which provides a path for clients to mount.

## Create a core filer
"Core filer" is a vFXT term for a storage system. It is most often a NAS like NetApp or Isilon. More information about core filers can be found [here](http://library.averesystems.com/ops_guide/4_7/settings_overview.html#managing-core-filers).
- From the Avere Control Panel, click the Settings tab at the top.
- Click “Manage Core Filers” on the left. 
- Click “Create.”
- Name your core filer.
- Provide a fully qualified domain name (FQDN) if available. Otherwise, provide an IP address or hostname that resolves to your core filer.
- Choose your filer class from the list. If unsure, choose “Other.”
- Click Next.

<img src="images/22addcorefiler1b">

- Choose a cache policy.
- Click “Add Filer.”
The page will refresh, or you can refresh the page to display your new core filer.

## Create a vserver
A vserver is a target for clients to mount to access storage. More information about vservers can be found [here](http://library.averesystems.com/ops_guide/4_7/settings_overview.html#creating-and-working-with-vservers)
- Click “Manage VServers” in the upper left.
- Click “Create.”
- Provide a name for your VServer.
- Provide the first and last IP addresses in an IP address range for your VServer
- Click “Next.”

<img src="images/23addvserver">

- After several seconds, click “Next” on the vserver confirmation page.
- Click “Next” on the “Configure a Directory Service” page.
The page will refresh and the vserver will be listed.

## Create a junction
A junction is a path that you create for clients. Clients mount the path in order to arrive at the destination you choose. For example, you could create `/avere/files` to map to your NetApp core filer, `/vol0/data` export, and the `/project/resources` subdirectory.
More information about junctions can be found [here](http://library.averesystems.com/ops_guide/4_7/gui_namespace.html).
- Click “Namespace” in the upper left.
- Provide a namespace path beginning with / (forward slash) like /avere/data.
- Choose your core filer.
- Choose the export.
- Click “Next.”

<img src="images/24addjunction">

The junction will appear after a few seconds. Create additional junctions as needed.