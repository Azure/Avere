# Additional configuration and reference 

After following the [quick start](https://github.com/Azure/Avere#quickstart) steps, you will have a functional vFXT cluster. This document outlines additional customizations that you might want to use, and gives links to reference documents where you can learn more about using and administering your vFXT cluster.  

Additional configuration tasks include:

- Enabling [support](enable_support.md) uploads and proactive service (recommended for all clusters)
- Copying data to cloud storage - Read [Moving data onto the vFXT cluster](getting_data_onto_vfxt.md) for details. 
- Customizing port accessibility - Read [Required ports](../required_ports.md) for more information.
- Configuring ExpressRoute or VPN access for clients - Refer to the [Azure ExpressRoute documentation](<https://docs.microsoft.com/en-us/azure/expressroute/>) or the [Azure VPN Gateway documentation](<https://docs.microsoft.com/en-us/azure/vpn-gateway/>) for details. 
- System tuning - Read [Cluster Tuning](tuning.md)  to learn more about adjusting custom settings for optimal performance in conjunction with Avere Global Services.

To learn how to add or remove cluster nodes, or to destroy the cluster, read [Managing the vFXT Cluster](start_stop_vfxt-py.md). 

## Avere Documentation

Additional Avere cluster documentation can be found on the  website at <http://library.averesystems.com/>.  These documents can help you understand the cluster's capabilities and how to configure its settings. 

- The [FXT Cluster Creation Guide](<http://library.averesystems.com/#fxt_cluster>) is designed for clusters made up of physical hardware nodes, but some information in the document is relevant for vFXT clusters as well. In particular, new vFXT cluster administrators can benefit from reading these sections:

    - [Customizing Support and Monitoring Settings](<http://library.averesystems.com/create_cluster/4_8/html/config_support.html#config-support>) <a name="uploads"> </a> explains how to customize support upload settings and enable remote monitoring. 

    - [Configuring VServers and Global Namespace](<http://library.averesystems.com/create_cluster/4_8/html/config_vserver.html#config-vserver>) has information about creating a client-facing namespace.

    - [Configuring DNS for the Avere cluster](<http://library.averesystems.com/create_cluster/4_8/html/config_network.html#dns-overview>) <a name="rrdns"> </a> explains how to configure round-robin DNS.

    - [Adding Backend Storage](<http://library.averesystems.com/create_cluster/4_8/html/config_core_filer.html#add-core-filer>) documents how to add core filers.

- The [Cluster Configuration Guide](<http://library.averesystems.com/#operations>) is a complete reference of settings and options for an Avere cluster. A vFXT cluster uses a subset of these options, but most of the same configuration pages apply.

- The [Dashboard Guide](<http://library.averesystems.com/#operations>) explains how to use the cluster monitoring features of the Avere Control Panel.

