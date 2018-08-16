# Managing instances

This section explains how to stop, restart, and destroy cloud instances that serve as vFXT cluster nodes.

There are several options for stopping, starting and removing vFXT clusters:

- [vfxt.py](#using-vfxt.py-to-manage-a-cluster) - The cluster creation script can be used to safely stop or destroy the entire cluster from the command line.
- [Azure portal](#actions-from-the-azure-portal) - The portal can be used to destroy cluster VMs individually, but data integrity is not guaranteed if the cluster is not shut down cleanly first.
- [Avere Control Panel](#avere-control-panel-actions) - The cluster administrative tool can be used to stop or reboot single nodes as well as the entire cluster. It is the safest option to guarantee that changed cache data is written to backend storage before shutdown.

## Using vfxt.py to manage a cluster 

The vfxt.py script includes options to stop, restart, or destroy a cluster. It cannot operate on individual nodes. 

**Stop a cluster:** 

    vfxt.py --cloud-type azure --from-environment --stop --resource-group GROUPNAME --admin-password PASSWORD --management-address ADMIN_IP

**Restart a stopped cluster:** 

    vfxt.py --cloud-type azure --from-environment --start --resource-group GROUPNAME --admin-password PASSWORD --instances INSTANCE1_ID INSTANCE2_ID INSTANCE3_ID ...

**Destroy a cluster:**

    vfxt.py --cloud-type azure --from-environment --destroy --resource-group GROUPNAME --admin-password PASSWORD --management-address ADMIN_IP

This example works for a running cluster; if the cluster is stopped you must pass instance identifiers to specify the cluster nodes.

The option ``--quick-destroy`` can be used if you do not want to write changed data from the cluster cache.

Read the [vfxt.py usage guide](<https://download.averesystems.com/software/avere_vfxt.py_usage_guide.pdf>) for additional information.  


## Avere Control Panel actions

### Stopping or rebooting one or more nodes

The Avere Control Panel can be used to stop or reboot individual nodes, as well as to stop or reboot the entire cluster.

The **FXT Nodes** settings page has controls for shutting down or rebooting individual nodes.(Note that IP addresses might move among cluster nodes when the number of active nodes changes.) Read [Cluster > FXT Nodes](<http://library.averesystems.com/ops_guide/4_7/gui_fxt_nodes.html#gui-fxt-nodes>) for more information.

To stop or reboot the entire cluster, use the **System Maintenance** settings page. Read [Administration > System Maintenance](<http://library.averesystems.com/ops_guide/4_7/gui_system_maintenance.html#gui-system-maintenance>) for details.

If you need to stop an instance or the entire cluster but do not intend to restart it, you can delete the instance by using tools in the Azure portal. See :ref:`terminate_instance` for more information.

>[AZURE.NOTE] Although compute charges are not incurred while instances are stopped, storage charges continue, including for the storage volume used for the node's operating system and local cache storage. A node in this state shows as **stopped** in the Azure portal. A node with the status **stopped (deallocated)** no longer incurs charges because its infrastructure disks have been removed.

### Removing a node from the cluster 

The [Cluster > FXT Nodes](<http://library.averesystems.com/ops_guide/4_7/gui_fxt_nodes.html#gui-fxt-nodes>) settings page in the Avere Control Panel is the best way to permanently remove a node from the cluster without affecting cluster operation. Find the node in the **FXT Nodes** page and click its **Remove** button.

### Rebooting or shutting down the cluster

The [Administration > System Maintenance](<http://library.averesystems.com/ops_guide/4_7/gui_system_maintenance.html#gui-system-maintenance>) settings page has commands for restarting services, rebooting the cluster, or safely powering the cluster down.

When shutting down a cluster, the cluster will initially post state messages to the **Dashboard** tab, but eventually the Avere Control Panel session will stop responding, indicating that the cluster has shut down.  



## Actions from the Azure portal

The Azure portal can be used for the following actions: 

- Restarting stopped vFXT nodes 
- Permanently destroying and removing cluster resources.
- Destroying a vFXT cluster if you do not need to ensure that any changed data in the cluster cache is written to the core filer

### Restarting vFXT instances

If you need to restart a stopped instance, you must use the Azure portal. Select **Virtual machines** in the left menu and then click on the VM name in the list to open its overview page.

Click the **Start** button at the top of the overview page to reactivate the VM.

![Azure Portal screen showing the option to start a stopped vm](images/start_stopped_incurring-annot.png)

### Deleting cluster nodes

If you want to delete one node from the vFXT cluster but keep the remainder of the cluster, you must first remove the node from the cluster using the Avere Control Panel.

>[AZURE.CAUTION] If you delete a node without first removing it from the vFXT cluster, data might be lost.

To permanently destroy one or more instances used as vFXT node, use the Azure portal.
Select **Virtual machines** in the left menu and then click on the VM name in the list to open its overview page.

Click the **Delete** button at the top of the overview page to permanently destroy the VM.

### Destroying the cluster from the Azure portal

>[AZURE.NOTE] If you want any remaining client changes in the cache to be written to backend storage, either use the vfxt.py ``--destroy`` option or use the Avere Control Panel to shut down the cluster cleanly before removing the node instances in the Azure portal.

You can destroy node instances permanently by deleting them in the Azure portal. You can delete them one at a time as described above in :ref:`node_terminate` or you can use the **Virtual Machines** page to find all of the cluster VMs, select them with the checkboxes, and click the **Delete** button to remove them all in one action.

![List of VMs in the portal, filtered by the term "cluster", with three of the four checked and highlighted](/images/multi_vm_delete.png)


