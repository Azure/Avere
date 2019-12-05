# Azure Artist Anywhere

Azure Artist Anywhere is a set of <a href="https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview" target="_blank">Azure Resource Manager (ARM)</a> templates and <a href="https://github.com/PowerShell/PowerShell/releases/latest" target="_blank">PowerShell Core</a> scripts for the automated deployment of an end-to-end media rendering solution in Azure. By structuring the solution as a set of parameterized and customizable templates, it provides a lightweight framework that can be modified and extended to meet various solution and deployment requirements.

Azure Artist Anywhere is composed with the following open-source software and Azure services:

* <a href="https://www.opencue.io/" target="_blank">OpenCue Render Farm Manager</a>

* <a href="https://docs.microsoft.com/en-us/azure/postgresql/overview" target="_blank">Azure Database for PostgreSQL</a>

* <a href="https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview" target="_blank">Azure Virtual Network</a>

* <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/" target="_blank">Azure Virtual Machines</a>

* <a href="https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview" target="_blank">Azure Virtual Machine Scale Sets</a>

* <a href="https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction" target="_blank">Azure NetApp Files</a>

* <a href="https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-overview" target="_blank">Azure Blob Storage</a>

* <a href="https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview" target="_blank">Azure HPC Cache</a>

* <a href="https://docs.microsoft.com/en-us/azure/dns/private-dns-overview" target="_blank">Azure Private DNS</a>

* <a href="https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview" target="_blank">Azure Load Balancer</a>

* <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/linux/shared-image-galleries" target="_blank">Azure Shared Image Gallery</a>

* <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-overview" target="_blank">Azure Image Builder</a>

The following overview diagram depicts the high-level solution architecture, which includes multiple options for hybrid networking and storage filers.

![](README.SolutionArchitecture.png)

The following diagram depicts the 3 parallel deployment processes (1 main + 2 background jobs) that are used to efficiently deploy the entire solution.

![](README.ParallelDeployment.png)

For more information, contact Rick Shahid (rick.shahid@microsoft.com)