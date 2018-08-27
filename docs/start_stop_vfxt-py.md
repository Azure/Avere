# Managing instances

This section explains how to stop, restart, and destroy cloud instances that serve as vFXT cluster nodes.

There are several options for stopping, starting and removing vFXT clusters:

- [vfxt.py](#using-vfxt.py-to-manage-a-cluster) - The cluster creation script can be used to safely stop or destroy the entire cluster from the command line.
- [Avere Control Panel](start_stop_gui.md) - The cluster administrative tool can be used to stop or reboot single nodes as well as the entire cluster. It is the safest option to guarantee that changed cache data is written to backend storage before shutdown.
- [Azure portal](start_stop_portal.md) - The portal can be used to destroy cluster VMs individually, but data integrity is not guaranteed if the cluster is not shut down cleanly first.


This document covers the simplest method, using vfxt.py. For more complicated actions, read the documents linked above. 

## Using vfxt.py to manage a cluster 

The vfxt.py script includes options to stop, restart, or destroy a cluster. It cannot operate on individual nodes. 

### Stop a cluster

```bash
vfxt.py --cloud-type azure --from-environment --stop --resource-group GROUPNAME --admin-password PASSWORD --management-address ADMIN_IP --location LOCATION --azure-network NETWORK --azure-subnet SUBNET
```

### Restart a stopped cluster

```bash
vfxt.py --cloud-type azure --from-environment --start --resource-group GROUPNAME --admin-password PASSWORD --management-address ADMIN_IP --location LOCATION --azure-network NETWORK --azure-subnet SUBNET --instances INSTANCE1_ID INSTANCE2_ID INSTANCE3_ID ...
```    

Because the cluster is stopped, you must pass instance identifiers to specify the cluster nodes.

### Destroy a cluster

```bash
vfxt.py --cloud-type azure --from-environment --destroy --resource-group GROUPNAME --admin-password PASSWORD --management-address ADMIN_IP --location LOCATION --azure-network NETWORK --azure-subnet SUBNET --management-address ADMIN_IP
```

The option ``--quick-destroy`` can be used if you do not want to write changed data from the cluster cache.

Read the [vfxt.py usage guide](<https://download.averesystems.com/software/avere_vfxt.py_usage_guide.pdf>) for additional information.  


