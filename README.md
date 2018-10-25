<img src="docs/images/avere_vfxt.png">

# Avere vFXT  

The Avere vFXT is an enterprise-scale clustered file system built for the cloud. It provides scalability, flexibility, and easy access to data stored in the cloud, in a datacenter, or both. High-performance computing workloads are supported with automatic hot data caching close to Azure Compute resources. 

## Quickstart

These quickstart steps walk you through creating a simple Avere vFXT cluster, setting up storage, and connecting clients.

  1. [Prerequisites](docs/prereqs.md) - Preparation tasks before deploying the Avere vFXT for Azure
  2. [Deploy](docs/jumpstart_deploy.md) - Create the vFXT cluster
  3. [Access the cluster](docs/access_cluster.md) - Access the Avere Control Panel from an SSH tunnel
  4. [Enable support](docs/enable_support.md) - Enable support for the cluster
  5. [Configure storage](docs/configure_storage.md) - Add backend storage (core filer and namespace junction)
  6. [Mount the Avere vFXT cluster](docs/mount_clients.md) - Configure load balancing and connect clients
  
## How-to guides

These guides explain next steps for putting the vFXT cluster through its paces. 

  * [Add data to the vFXT cluster](docs/getting_data_onto_vfxt.md) - Parallel copy strategies to efficiently load data onto cluster storage
  * [Manage the cluster](docs/start_stop_vfxt-py.md) - How to stop, start, or decommission the cluster, and manage cluster nodes
  * [Additional configuration and reference](docs/additional_config.md) - Additional cluster setup tasks and links to supplemental documentation 
  * [Cluster performance tuning](docs/tuning.md) - Custom performance optimizations
  * [Troubleshooting and getting support](docs/engage_support.md)

## Concepts

  * [Cloud bursting overview](/docs/cloud_bursting.md)
  * [Cloud NAS overview](/docs/cloud_nas.md)

## Tutorials

These tutorials help you understand cluster performance testing and common use-case tasks.

  * [Virtual Machine Client Implementations that mount the Avere vFXT Edge Filer](docs/clients.md) - This tutorial discusses how to deploy and mount 3 types of virtual machines: loose VMs, VM availability sets (VMAS), and VM scale sets (VMSS).
  * [Measure vFXT performance with vdbench](docs/vdbench.md) - Deploys vdbench on an *N*-node cluster to demonstrate the storage performance characteristics of the Avere vFXT cluster
  * [Data Ingestor](docs/data_ingestor.md) - This tutorial implements a data ingestor containing the tools required to efficiently load data onto the Avere vFXT Edge Filer.
  * [Rendering using Azure Batch and Avere vFXT](docs/maya_azure_batch_avere_vfxt_demo.md) - Demonstrates how to use the Autodesk Maya Renderer with Azure Batch and the Avere vFXT cluster to generate a rendered movie.
  * [Why use the Avere vFXT for Rendering?](docs/why_avere_for_rendering.md) - Shows the results of rending against NFS at various latencies and how Avere vFXT hides the latency.
  * [Best Practices for Improving Azure Virtual Machine (VM) Boot Time](docs/azure_vm_provision_best_practices.md) - The Avere vFXT is commonly used with burstable compute workloads. We hear from our customers that it is very challenging to boot thousands of Azure virtual machines quickly. This article describes best practices for booting thousands of VMs in the fastest possible time.
  * [Windows 10 workstation for Avere vFXT](docs/windows_10_avere_vfxt_mounted_workstation.md) - Creates a Windows workstation within the same VNET as the Avere vFXT and automatically mounts the vFXT cluster and installs various Azure tools for debugging.
  
## Resources
  * [vFXT guides](http://library.averesystems.com/#vfxt) - Additional documentation about the Avere vFXT cluster
  * [vfxt.py usage](http://library.averesystems.com/#vfxt) - Usage guide for the vfxt.py script  
  * [FXT Cluster Creation Guide](http://library.averesystems.com/#fxt_cluster) - Although this guide is for creating clusters of physical FXT appliances, some configuration information is relevant for vFXT clusters as well. 
  * [Cluster Configuration Guide](http://library.averesystems.com/#operations) - A conceptual guide and complete settings reference for administering an Avere cluster. 
  * [Dashboard Guide](http://library.averesystems.com/#operations) - How to use the cluster monitoring features of the Avere Control Panel.

### Legal Notices

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

### Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
