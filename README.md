# Avere vFXT

<img src="docs/images/avere_vfxt.png">

The Avere vFXT is an enterprise-scale clustered file system built for the cloud.

# Cloud Bursting

Avere Virtual FXT (vFXT) Edge filers act as network-attached storage (NAS) on Azure compute cloud, freeing your data to remain on-premises, while giving you complete functionality. The Avere vFXT works to:

  * Connect your on-premises storage to Azure's services
  * Support for NFS, SMB and multi-protocol workloads
  * Allows you to offset peaks in compute demand with Azure's pay-as-you-go services without moving large data sets from existing storage
  * Hides latency to cloud compute resources with cloud caching
  * Provides easy scaling from 3 to 24 nodes to meet growing demands in shorter periods of time
  * Reduces cloud compute costs by as much as 90% by minimizing the use of Azure Storage during processing
  * Eliminates the need to expand owned compute capacity, reducing data center footprint and supporting data center consolidation
  * Allows for use of Microsoft Azure Low-priority Virtual Machines for additional savings
  * Enterprises and companies working within HPC environments see immediate benefits of flexibility and agility to match compute resources with business demands quickly and easily.

[Learn more about Cloud Bursting](http://www.averesystems.com/cloud-bursting)

<img src="http://www.averesystems.com/UserFiles/Image/CloudBurst.gif">

# Clustered File System for Azure – Cloud NAS

When using both Azure Storage and Azure Compute resources, you can use the vFXT to create an enterprise-grade NAS in the public cloud, eliminating the silos between these resources. Leverage low-cost Azure Storage for applications running on Azure Compute.

Avere Cloud NAS with the vFXT for Azure gives you:
  * Scalability – clustering up to 24 nodes
  * Low Data Latency – powerful cloud cache tiers data for optimal performance
  * Secure AES 256-encryption
  * Protection with Cloud Snapshots
  * Insights with powerful analytics

[Learn more about Cloud NAS](http://www.averesystems.com/cloud-nas)

<img src="http://www.averesystems.com/UserFiles/Image/CloudNas.gif">

# Documentation
  * [Prerequisites](docs/prereqs.md)
  * [Jumpstart Deployment](docs/jumpstart_deploy.md) - The fastest way to create a vFXT cluster.
  * [Access the cluster](docs/access_cluster.md) - Access the Avere Control Panel from an SSH tunnel
  * [Configure storage](docs/configure_storage.md) - Add a core filer, vserver, and junction
  * (Erin/Ron) Connecting clients - RRDNS and `mount`
  * [Getting data onto the vFXT cluster](docs/getting_data_onto_vfxt.md) - provides various strategies for how to parallelize ingress to the vFXT.
  * (Erin) Management – start / stop
  * (Erin) Tune / Optimize
  * [Troubleshoot – engage support](docs/engage_support.md)

# Quick Start Guides
  * [Avere vFXT deployment](docs/avere_vfxt_deployment.md) - A quickstart guide to deploy the vFXT into an empty environment.
  * [Using the vFXT](docs/using_the_vfxt.md) - This introduces you to the parallelization required for the vFXT.
  * [VDBench - measuring vFXT Performance](docs/vdbench.md) - Deploys VDBench on an N-Node cluster to demonstrate the storage performance characteristics of the Avere vFXT cluster.
  * [Windows 10 Avere vFXT Mounted Workstation](docs/windows_10_avere_vfxt_mounted_workstation.md) - Creates a Windows Workstation that automatically mounts the vFXT, and installs various Azure Tools.
  * [Maya + Azure Batch + Avere vFXT Demo](docs/maya_azure_batch_avere_vfxt_demo.md) - Demonstrates how to use the Autodesk Maya Renderer with Azure Batch and the Avere vFXT to generate a rendered movie.

# Resources
  * [vFXT Guides](http://library.averesystems.com/#vfxt) 
  * [fxt_cluster](http://library.averesystems.com/#fxt_cluster) - this guide is designed for clusters of physical hardware nodes, but some information in the document is relevant for vFXT clusters as well. In particular, these sections can be useful for vFXT cluster administrators: 
    * [Gui login](http://library.averesystems.com/create_cluster/4_8/html/initial_config.html#gui-login) - explains how to connect to the Avere Control Panel and log in. However, note that you must use a VPN or SSH tunnel to access the cluster nodes inside the|aws|VPC. Read node_ssl_tunnel for details.
    * [Config vServer](http://library.averesystems.com/create_cluster/4_8/html/config_vserver.html#config-vserver) - has information about creating a client-facing namespace
    * [Add Core Filer](http://library.averesystems.com/create_cluster/4_8/html/config_core_filer.html#add-core-filer) - documents how to add storage
    * [Config Support](http://library.averesystems.com/create_cluster/4_8/html/config_support.html#config-support) - explains how to customize support settings and remote monitoring. 
    * [Cluster Configuration Guide](http://library.averesystems.com/#operations) - is a complete reference of settings and options for an Avere cluster. A vFXT cluster uses a subset of these options, but many of the same configuration pages apply. 
    * [Dashboard guide](http://library.averesystems.com/#operations) - explains how to use the cluster monitoring features of the Avere Control Panel.

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

# Legal Notices

Microsoft and any contributors grant you a license to the Microsoft documentation and other content
in this repository under the [Creative Commons Attribution 4.0 International Public License](https://creativecommons.org/licenses/by/4.0/legalcode),
see the [LICENSE](LICENSE) file, and grant you a license to any code in the repository under the [MIT License](https://opensource.org/licenses/MIT), see the
[LICENSE-CODE](LICENSE-CODE) file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products and services referenced in the documentation
may be either trademarks or registered trademarks of Microsoft in the United States and/or other countries.
The licenses for this project do not grant you rights to use any Microsoft names, logos, or trademarks.
Microsoft's general trademark guidelines can be found at http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/en-us/

Microsoft and any contributors reserve all others rights, whether under their respective copyrights, patents,
or trademarks, whether by implication, estoppel or otherwise.
