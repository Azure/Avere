# Azure Artist Anywhere ([aka.ms/aaa](http://aka.ms/aaa))

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/azure/azure-resource-manager/management/overview) templates for automated deployment of an end-to-end rendering solution in Microsoft Azure. Azure Artist Anywhere provides a lightweight and extensible framework with the storage tier in Azure or storage on-premises with integration via [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview).

As a sample, the following image was rendered on [Azure HPC VMs](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-hpc) via an [Azure Virtual Machine Scale Set (VMSS)](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview) using [V-Ray for Maya](https://www.chaosgroup.com/vray/maya).

![](https://amp.blob.core.windows.net/doc/AzureArtistAnywhere.SuspensionBridge.jpg)

The following Microsoft Azure services and 3rd-party software are integrated within the Azure Artist Anywhere rendering solution.

<table>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview" target="_blank">Azure Virtual Network</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/storage" target="_blank">Azure Storage</a>
            (<a href="https://docs.microsoft.com/azure/storage/files/storage-files-introduction" target="_blank">Files</a>,
            <a href="https://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview" target="_blank">Objects</a>)
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview" target="_blank">Azure HPC Cache</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/cyclecloud/overview" target="_blank">Azure Cycle Cloud</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways" target="_blank">Azure Virtual Network Gateway</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction" target="_blank">Azure NetApp Files</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/private-link/private-link-overview" target="_blank">Azure Private Link</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/batch/batch-technical-overview" target="_blank">Azure Batch</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview" target="_blank">Azure Managed Identity</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/shared-image-galleries" target="_blank">Azure Shared Image Gallery</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/dns/private-dns-overview" target="_blank">Azure Private DNS</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/azure-functions/functions-overview" target="_blank">Azure Functions</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/key-vault/key-vault-overview" target="_blank">Azure Key Vault</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-overview" target="_blank">Azure Image Builder</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/container-registry/container-registry-intro" target="_blank">Azure Container Registry</a>
        </td>
        <td>
            <a href="https://www.blender.org/" target="_blank">Blender Content Creation Suite</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/azure-monitor/overview" target="_blank">Azure Monitor</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/overview" target="_blank">Azure Virtual Machines</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/cosmos-db/introduction" target="_blank">Azure Cosmos (Mongo) DB</a>
        </td>
        <td>
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Management</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/event-grid/overview" target="_blank">Azure Event Grid</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview" target="_blank">Azure Virtual Machine Scale Sets</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/postgresql/overview" target="_blank">Azure Database for PostgreSQL</a>
        </td>
        <td>
            <a href="https://docs.teradici.com/find/product/cloud-access-software" target="_blank">Teradici Remote Access (PCoIP)</a>
        </td>
    </tr>
</table>

## Solution Architecture

The following overview diagram depicts the Azure Artist Anywhere solution architecture, including on-premises storage asset caching.

![](https://amp.blob.core.windows.net/doc/AzureArtistAnywhere.SolutionArchitecture.png)

## Deployment Modules

The following Microsoft Azure resource templates and scripts define the Azure Artist Anywhere deployment modules.

| *Base Framework* | *Storage Cache* | *Render Manager* |
| :----------------- | :-------------- | :--------------- |
| 00 - [Virtual Network](BaseFramework/00-VirtualNetwork.json) ([Parameters](BaseFramework/00-VirtualNetwork.Parameters.json)) | 07 - [Storage](StorageCache/07-Storage.json) ([Parameters](StorageCache/07-Storage.Parameters.json)) | 10 - [Database](RenderManager/10-Database.json) ([Parameters](RenderManager/10-Database.Parameters.json)) |
| 01 - [Managed Identity](BaseFramework/01-ManagedIdentity.json) ([Parameters](BaseFramework/01-ManagedIdentity.Parameters.json)) | 07 - [Storage NetApp](StorageCache/07-Storage.NetApp.json) ([Parameters](StorageCache/07-Storage.NetApp.Parameters.json)) | 11 - [Image](RenderManager/11-Image.json) ([Parameters](RenderManager/11-Image.Parameters.json)) |
| 02 - [Key Vault](BaseFramework/02-KeyVault.json) ([Parameters](BaseFramework/02-KeyVault.Parameters.json)) | 07 - [* Storage Qumulo](StorageCache/07-Storage.Qumulo.json) ([Parameters](StorageCache/07-Storage.Qumulo.Parameters.json)) | 11 - Image Customize ([Linux](RenderManager/11-Image.sh), [Windows](RenderManager/11-Image.ps1)) |
| 03 - [Network Gateway](BaseFramework/03-NetworkGateway.json) ([Parameters](BaseFramework/03-NetworkGateway.Parameters.json)) | 07 - [* Storage Scality](StorageCache/07-Storage.Scality.json) ([Parameters](StorageCache/07-Storage.Scality.Parameters.json)) | 12 - [Machine](RenderManager/12-Machine.json) ([Parameters](RenderManager/12-Machine.Parameters.json)) |
| 04 - [Pipeline Insight](BaseFramework/04-PipelineInsight.json) ([Parameters](BaseFramework/04-PipelineInsight.Parameters.json)) | 08 - [HPC Cache](StorageCache/08-HPCCache.json) ([Parameters](StorageCache/08-HPCCache.Parameters.json)) | 12 - Machine Initialize ([Linux](RenderManager/12-Machine.sh), [Windows](RenderManager/12-Machine.ps1)) |
| 05 - [Image Gallery](BaseFramework/05-ImageGallery.json) ([Parameters](BaseFramework/05-ImageGallery.Parameters.json)) | 09 - [Event Grid](StorageCache/09-EventGrid.json) ([Parameters](StorageCache/09-EventGrid.Parameters.json)) | 13 - [Cycle Cloud](RenderManager/13-CycleCloud.json) ([Parameters](RenderManager/13-CycleCloud.Parameters.json)) |
| 06 - [Container Registry](BaseFramework/06-ContainerRegistry.json) ([Parameters](BaseFramework/06-ContainerRegistry.Parameters.json)) | | 14 - [Batch Account](RenderManager/14-BatchAccount.json) ([Parameters](RenderManager/14-BatchAccount.Parameters.json)) |

\* = TBD

| *Render Farm (Linux)* | *Render Farm (Windows)* |
| :-------------------- | :---------------------- |
| 15 - [Node Image](RenderFarm/15-Node.Image.json) ([Parameters](RenderFarm/15-Node.Image.Parameters.json)) | 15 - [Node Image](RenderFarm/15-Node.Image.json) ([Parameters](RenderFarm/15-Node.Image.Parameters.json)) |
| 15 - [Node Image Customize](RenderFarm/Linux/15-Node.Image.sh) | 15 - [Node Image Customize](RenderFarm/Windows/15-Node.Image.ps1) |
| 15 - [Node Image Customize (Blender)](RenderFarm/Linux/15-Node.Image.Blender.sh) | 15 - [Node Image Customize (Blender)](RenderFarm/Windows/15-Node.Image.Blender.ps1) |
| 15 - [Node Image Customize (OpenCue)](RenderFarm/Linux/15-Node.Image.OpenCue.sh) | 15 - [Node Image Customize (OpenCue)](RenderFarm/Windows/15-Node.Image.OpenCue.ps1) |
| 15 - [* Node Image Customize (Deadline)](RenderFarm/Linux/15-Node.Image.Deadline.sh) | 15 - [* Node Image Customize (Deadline)](RenderFarm/Windows/15-Node.Image.Deadline.ps1) |
| 16 - [Farm Pool](RenderFarm/16-Farm.Pool.json) ([Parameters](RenderFarm/16-Farm.Pool.Parameters.json)) | 16 - [Farm Pool](RenderFarm/16-Farm.Pool.json) ([Parameters](RenderFarm/16-Farm.Pool.Parameters.json)) |
| 16 - [Farm Scale Set](RenderFarm/16-Farm.ScaleSet.json) ([Parameters](RenderFarm/16-Farm.ScaleSet.Parameters.json)) | 16 - [Farm Scale Set](RenderFarm/16-Farm.ScaleSet.json) ([Parameters](RenderFarm/16-Farm.ScaleSet.Parameters.json)) |
| 16 - [Farm Scale Set Initialize](RenderFarm/Linux/16-Farm.ScaleSet.sh) | 16 - [Farm Scale Set Initialize](RenderFarm/Windows/16-Farm.ScaleSet.ps1) |

\* = TBD

| *Artist Workstation (Linux)* | *Artist Workstation (Windows)* |
| :--------------------------- | :----------------------------- |
| 17 - [Image](ArtistWorkstation/17-Image.json) ([Parameters](ArtistWorkstation/17-Image.Parameters.json)) | 17 - [Image](ArtistWorkstation/17-Image.json) ([Parameters](ArtistWorkstation/17-Image.Parameters.json)) |
17 - [Image Customize](ArtistWorkstation/Linux/17-Image.sh) | 17 - [Image Customize](ArtistWorkstation/Windows/17-Image.ps1) |
17 - [Image Customize (Blender)](RenderFarm/Linux/15-Node.Image.Blender.sh) | 17 - [Image Customize (Blender)](RenderFarm/Windows/15-Node.Image.Blender.ps1) |
17 - [Image Customize (OpenCue)](ArtistWorkstation/Linux/17-Image.OpenCue.sh) | 17 - [Image Customize (OpenCue)](ArtistWorkstation/Windows/17-Image.OpenCue.ps1) |
17 - [* Image Customize (Deadline)](RenderFarm/Linux/15-Node.Image.Deadline.sh) | 17 - [* Image Customize (Deadline)](RenderFarm/Windows/15-Node.Image.Deadline.ps1) |
17 - [Image Customize (Teradici)](ArtistWorkstation/Linux/17-Image.Teradici.sh) | 17 - [Image Customize (Teradici)](ArtistWorkstation/Windows/17-Image.Teradici.ps1) |
18 - [Machine](ArtistWorkstation/18-Machine.json) ([Parameters](ArtistWorkstation/18-Machine.Parameters.json)) | 18 - [Machine](ArtistWorkstation/18-Machine.json) ([Parameters](ArtistWorkstation/18-Machine.Parameters.json)) |
18 - [Machine Initialize](ArtistWorkstation/Linux/18-Machine.sh) | 18 - [Machine Initialize](ArtistWorkstation/Windows/18-Machine.ps1) |

\* = TBD

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
