
# Post-creation configuration  

The vfxt.py utility creates and configures the vFXT cluster. To administer the finished cluster, use the Avere Control Panel. Although many settings are set appropriately for your cloud service by the creation script, there are others that you might want to customize.

Post-creation configuration tasks include the following:

- Establishing a [virtual namespace](#gns) and client mount points
- Configuring [round-robin DNS](#rrdns) to balance client service requests among the cluster nodes
- Adding [backend storage](#rrdns) (these can be cloud resources or hardware NAS systems)
- Copying data to cloud storage - Read [Moving data onto the vFXT cluster](getting_data_onto_vfxt.md) for details. 
- Customizing port accessibility - Read [HTTPS access for cluster nodes](node_access.md) for more information.
- Setting up proxy servers if needed - **[ xxx should this reference our ops guide or an Azure page? xxx ]**
- Configuring ExpressRoute or VPN access for clients - Refer to the [Azure ExpressRoute documentation](<https://docs.microsoft.com/en-us/azure/expressroute/>) or the [Azure VPN Gateway documentation](<https://docs.microsoft.com/en-us/azure/vpn-gateway/>) for details. 
- Enabling [support](#uploads) uploads and proactive service
- Configuring AD or other directory services **[ xxx should this reference our ops guide or an Azure page? xxx ]**
- System tuning - Read [Cluster Tuning](#cluster-tuning)  to learn more about adjusting custom settings for optimal performance in conjunction with Avere Global Services.

To learn how to add or remove cluster nodes, or to destroy the cluster, read [Managing the vFXT Cluster](manage_cluster.md). 

The vfxt.py utility creates and configures the vFXT cluster. To administer the finished cluster, use the Avere Control Panel. Although many settings are set appropriately for your cloud service by the creation script, there are others that you might want to customize.

The [FXT Cluster Creation Guide](<http://library.averesystems.com/#fxt_cluster>) is designed for clusters of physical hardware nodes, but some information in the document is relevant for vFXT clusters as well. In particular, these sections can be useful for vFXT cluster administrators: 

- [Logging in to the Avere Control Panel](<http://library.averesystems.com/create_cluster/4_8/html/initial_config.html#gui-login>) explains how to connect to the Avere Control Panel and log in. However, note that you might need to use the cluster controller as a jump host to access the Avere Control Panel because it runs on the cluster inside the private virtual network. Read [Accessing vFXT nodes](<cluster_manage.md#node-ssl-tunnel>) for details.

- <a name="gns"> </a> [Configuring VServers and Global Namespace](<http://library.averesystems.com/create_cluster/4_8/html/config_vserver.html#config-vserver>) has information about creating a client-facing namespace.

- [Configuring DNS for the Avere cluster](<http://library.averesystems.com/create_cluster/4_8/html/config_network.html#dns-overview>) <a name="rrdns"> </a> explains how to configure round-robin DNS.

- [Adding Backend Storage](<http://library.averesystems.com/create_cluster/4_8/html/config_core_filer.html#add-core-filer>) documents how to add storage.

- [Customizing Support and Monitoring Settings](<http://library.averesystems.com/create_cluster/4_8/html/config_support.html#config-support>) <a name="uploads"> </a> explains how to customize support upload settings and enable remote monitoring. 

These additional documents also might be helpful: 

- The [Cluster Configuration Guide](<http://library.averesystems.com/#operations>) is a complete reference of settings and options for an Avere cluster. A vFXT cluster uses a subset of these options, but many of the same configuration pages apply.

- The [Dashboard Guide](<http://library.averesystems.com/#operations>) explains how to use the cluster monitoring features of the Avere Control Panel.

Current documents can be found on the documentation website at http://library.averesystems.com/.  

## Cluster tuning

Because of the diverse software and hardware environments used with the Avere cluster, and differing customer requirements, many VvFXT clusters can benefit from customized performance settings. This step is typically done in conjunction with an Avere Systems representative, since it involves configuring some features that are not accessible in the Avere Control Panel.

The VDBench utlity can be helfpul in generating I/O workloads to test a vFXT cluster. Read [Measuring vFXT Performance](vdbench.md) to learn more. 

This section gives some examples of the kinds of custom tuning that can be done.

### General-use optimizations

These changes might be recommended based on dataset qualities or workflow style. 

- If the workload is write-heavy, increase the size of the write cache from its default of 20%. 

- If the dataset involves many small files, increase the cluster cache's file count limit. 

- If the work involves copying or moving data between two repositories, increase the number of parallel threads for moving data - or decrease the number of parallel threads if the back-end storage is becoming overloaded

- If the cluster is caching data for a core filer that uses NFSv4 ACLs, enable access mode caching to streamline file authorization for particular clients.

### Cloud NAS or cloud gateway optimizations

To take advantage of higher data speeds between the VvFXT cluster and cloud storage in a cloud NAS or gateway scenario (where the VvFXT cluster provides NAS-style access to a cloud container), Avere might recommend changing settings like these to more aggressively push data to the storage volume from the cache: 

- Increasing the number of TCP connections between the cluster and the storage container
- Decreasing the protocol timeout value for communication between the cluster and storage to retry writes that don't immediately succeed sooner **[ xxx this was "REST timeout" - is that accurate? Should I just say REST timeout value? xxx ]**
- Increase the segment size so that each backend write segment transfers an 8MB chunk of data instead of 1MB

### Cloud bursting or hybrid WAN optimizations

In a cloud bursting scenario or hybrid storage WAN optimization scenario (where the vFXT cluster provides integration between the cloud and on-premises hardware storage), these changes can be helpful:

- Increase the number of TCP connections allowed between the cluster and the core filer
- Enable the WAN Optimization setting for the remote core filer (This can be used for a remote on-premises filer or a cloud core filer in a different Azure region.)
- Increase the TCP socket buffer size (depending on workload and performance needs)
- Enable the "always forward" setting to reduce redundantly cached files (depending on workload and performance needs)
