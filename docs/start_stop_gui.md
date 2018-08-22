# Managing instances with the Avere Control Panel

There are several options for stopping, starting and removing vFXT clusters:

- [vfxt.py](start_stop_vfxt-py.md) - The cluster creation script can be used to safely stop or destroy the entire cluster from the command line.
- [Azure portal](start_stop_portal.md) - The portal can be used to destroy cluster VMs individually, but data integrity is not guaranteed if the cluster is not shut down cleanly first.
- Avere Control Panel - The cluster administrative tool can be used to stop or reboot single nodes as well as the entire cluster. It is the safest option to guarantee that changed cache data is written to backend storage before shutdown.

This document explains actions available from the Avere Control Panel administrative interface. Read the linked documents above to learn about other options for controlling cluster nodes and VMs. 

## Stopping or rebooting one or more nodes

The Avere Control Panel can be used to stop or reboot individual nodes, as well as to stop or reboot the entire cluster.

The **FXT Nodes** settings page has controls for shutting down or rebooting individual nodes.(Note that IP addresses might move among cluster nodes when the number of active nodes changes.) Read [Cluster > FXT Nodes](<http://library.averesystems.com/ops_guide/4_7/gui_fxt_nodes.html#gui-fxt-nodes>) for more information.

To stop or reboot the entire cluster, use the **System Maintenance** settings page. Read [Administration > System Maintenance](<http://library.averesystems.com/ops_guide/4_7/gui_system_maintenance.html#gui-system-maintenance>) for details.

**NOTE:** Although compute charges are not incurred while instances are stopped, storage charges continue, including for the storage volume used for the node's operating system and local cache storage. A node in this state shows as **stopped** in the Azure portal. A node with the status **stopped (deallocated)** no longer incurs charges because its infrastructure disks have been removed.

## Removing a node from the cluster 

The [Cluster > FXT Nodes](<http://library.averesystems.com/ops_guide/4_7/gui_fxt_nodes.html#gui-fxt-nodes>) settings page in the Avere Control Panel is the best way to permanently remove a node from the cluster without affecting cluster operation. Find the node in the **FXT Nodes** page and click its **Remove** button.

## Rebooting or shutting down the cluster

The [Administration > System Maintenance](<http://library.averesystems.com/ops_guide/4_7/gui_system_maintenance.html#gui-system-maintenance>) settings page has commands for restarting services, rebooting the cluster, or safely powering the cluster down.

When shutting down a cluster, the cluster will initially post state messages to the **Dashboard** tab, but eventually the Avere Control Panel session will stop responding, indicating that the cluster has shut down.  
