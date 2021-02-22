# Azure Artist Anywhere ([aka.ms/aaa](https://aka.ms/aaa))

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/azure/azure-resource-manager/management/overview) templates for automated deployment of an end-to-end rendering solution in Microsoft Azure. Azure Artist Anywhere provides a lightweight and customizable deployment framework with the storage tier in Azure and/or asset storage located on-premises with Azure compute integration via the [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) managed service.

As a simple example, the following 3D image was rendered via [Azure HPC Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-hpc) in an [Azure Virtual Machine Scale Set (VMSS)](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview).

![](https://bit.blob.core.windows.net/doc/AzureArtistAnywhere/SuspensionBridge.jpg)

## Solution Architecture

The following overview diagram depicts the Azure Artist Anywhere solution architecture, including on-premises storage asset caching.

![](https://bit.blob.core.windows.net/doc/AzureArtistAnywhere/SolutionArchitecture.png)

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
            <a href="https://docs.microsoft.com/azure/event-grid/overview" target="_blank">Azure Event Grid</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/azure-functions/functions-overview" target="_blank">Azure Functions</a>
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
            <a href="https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview" target="_blank">Azure HPC Cache</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/cyclecloud/overview" target="_blank">Azure CycleCloud</a>
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
            <a href="https://docs.microsoft.com/azure/private-link/private-link-overview" target="_blank">Azure Private Link</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/batch/batch-technical-overview" target="_blank">Azure Batch</a>
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
            <a href="https://docs.microsoft.com/azure/dns/private-dns-overview" target="_blank">Azure Private DNS</a>
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
            <a href="https://docs.microsoft.com/azure/container-registry/container-registry-intro" target="_blank">Azure Container Registry</a>
        </td>
        <td>
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Management</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview" target="_blank">Azure App Insight</a>
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

## Deployment Modules

The following Microsoft Azure resource templates and scripts define the Azure Artist Anywhere deployment modules.

| *Base Framework* | *Storage Cache* | *Event Integration* | *Image Library* |
| :--------------- | :-------------- | :---------------- | :-------------- |
| (01) [Virtual Network](BaseFramework/01-VirtualNetwork.json) ([Parameters](BaseFramework/01-VirtualNetwork.Parameters.json)) | (07) [Storage](StorageCache/07-Storage.json) ([Parameters](StorageCache/07-Storage.Parameters.json)) | (09) [* Event Grid](EventIntegration/09-EventGrid.json) ([Parameters](EventIntegration/09-EventGrid.Parameters.json)) | (11) [Image Gallery](ImageLibrary/11-ImageGallery.json) ([Parameters](ImageLibrary/11-ImageGallery.Parameters.json)) |
| (02) [Monitor Insight](BaseFramework/02-MonitorInsight.json) ([Parameters](BaseFramework/02-MonitorInsight.Parameters.json)) | (07) [Storage NetApp](StorageCache/07-Storage.NetApp.json) ([Parameters](StorageCache/07-Storage.NetApp.Parameters.json)) | (10) [* Function App](EventIntegration/10-FunctionApp.json) ([Parameters](EventIntegration/10-FunctionApp.Parameters.json)) | (12) [Container Registry](ImageLibrary/12-ContainerRegistry.json) ([Parameters](ImageLibrary/12-ContainerRegistry.Parameters.json)) |
| (03) [* Active Directory](BaseFramework/03-ActiveDirectory.json) ([Parameters](BaseFramework/03-ActiveDirectory.Parameters.json)) | (07) [* Storage Qumulo](StorageCache/07-Storage.Qumulo.json) ([Parameters](StorageCache/07-Storage.Qumulo.Parameters.json)) | | |
| (04) [Managed Identity](BaseFramework/04-ManagedIdentity.json) ([Parameters](BaseFramework/04-ManagedIdentity.Parameters.json)) | (07) [* Storage Hammerspace](StorageCache/07-Storage.Hammerspace.json) ([Parameters](StorageCache/07-Storage.Hammerspace.Parameters.json)) | | |
| (05) [Key Vault](BaseFramework/05-KeyVault.json) ([Parameters](BaseFramework/05-KeyVault.Parameters.json)) | (08) [HPC Cache](StorageCache/08-HPCCache.json) ([Parameters](StorageCache/08-HPCCache.Parameters.json)) |
| (06) [Network Gateway](BaseFramework/06-NetworkGateway.json) ([Parameters](BaseFramework/06-NetworkGateway.Parameters.json)) | | | |

\* = TBD

| *Render Manager (Linux)* | *Render Manager (Windows)* |
| :----------------------- | :------------------------- |
| (13) [Database](RenderManager/13-Database.json) ([Parameters](RenderManager/13-Database.Parameters.json)) | (13) [Database](RenderManager/13-Database.json) ([Parameters](RenderManager/13-Database.Parameters.json)) |
| (14) [Image](RenderManager/14-Image.json) ([Parameters](RenderManager/14-Image.Parameters.json)) | (14) [Image](RenderManager/14-Image.json) ([Parameters](RenderManager/14-Image.Parameters.json)) |
| (14) [Image Customize (OpenCue)](RenderManager/Linux/14-Image.OpenCue.sh) | (14) [* Image Customize (OpenCue)](RenderManager/Windows/14-Image.OpenCue.ps1) |
| (14) [* Image Customize (Royal Render)](RenderManager/Linux/14-Image.RoyalRender.sh) | (14) [* Image Customize (Royal Render)](RenderManager/Windows/14-Image.RoyalRender.ps1) |
| (15) [Machine](RenderManager/15-Machine.json) ([Parameters](RenderManager/15-Machine.Parameters.json)) | (15) [Machine](RenderManager/15-Machine.json) ([Parameters](RenderManager/15-Machine.Parameters.json)) |
| (15) [Machine Initialize](RenderManager/Linux/15-Machine.sh) | (15) [Machine Initialize](RenderManager/Windows/15-Machine.ps1) |
| (16) [CycleCloud](RenderManager/16-CycleCloud.json) ([Parameters](RenderManager/16-CycleCloud.Parameters.json)) | (16) [CycleCloud](RenderManager/16-CycleCloud.json) ([Parameters](RenderManager/16-CycleCloud.Parameters.json)) |
| (17) [Batch Account](RenderManager/17-BatchAccount.json) ([Parameters](RenderManager/17-BatchAccount.Parameters.json)) | (17) [Batch Account](RenderManager/17-BatchAccount.json) ([Parameters](RenderManager/17-BatchAccount.Parameters.json)) |

\* = TBD

| *Render Farm (Linux)* | *Render Farm (Windows)* |
| :-------------------- | :---------------------- |
| (18) [Node Image](RenderFarm/18-Node.Image.json) ([Parameters](RenderFarm/18-Node.Image.Parameters.json)) | (18) [Node Image](RenderFarm/18-Node.Image.json) ([Parameters](RenderFarm/18-Node.Image.Parameters.json)) |
| (18) [Node Image Customize](RenderFarm/Linux/18-Node.Image.sh) | (18) [Node Image Customize](RenderFarm/Windows/18-Node.Image.ps1) |
| (18) [Node Image Customize (Blender)](RenderFarm/Linux/18-Node.Image.Blender.sh) | (18) [Node Image Customize (Blender)](RenderFarm/Windows/18-Node.Image.Blender.ps1) |
| (18) [Node Image Customize (OpenCue)](RenderFarm/Linux/18-Node.Image.OpenCue.sh) | (18) [Node Image Customize (OpenCue)](RenderFarm/Windows/18-Node.Image.OpenCue.ps1) |
| (18) [* Node Image Customize (Royal Render)](RenderFarm/Linux/18-Node.Image.RoyalRender.sh) | (18) [* Node Image Customize (RoyalRender)](RenderFarm/Windows/18-Node.Image.RoyalRender.ps1) |
| (19) [Farm Pool](RenderFarm/19-Farm.Pool.json) ([Parameters](RenderFarm/19-Farm.Pool.Parameters.json)) | (19) [Farm Pool](RenderFarm/19-Farm.Pool.json) ([Parameters](RenderFarm/19-Farm.Pool.Parameters.json)) |
| (19) [Farm Scale Set](RenderFarm/19-Farm.ScaleSet.json) ([Parameters](RenderFarm/19-Farm.ScaleSet.Parameters.json)) | (19) [Farm Scale Set](RenderFarm/19-Farm.ScaleSet.json) ([Parameters](RenderFarm/19-Farm.ScaleSet.Parameters.json)) |
| (19) [Farm Scale Set Initialize](RenderFarm/Linux/19-Farm.ScaleSet.sh) | (19) [Farm Scale Set Initialize](RenderFarm/Windows/19-Farm.ScaleSet.ps1) |

\* = TBD

| *Artist Workstation (Linux)* | *Artist Workstation (Windows)* |
| :--------------------------- | :----------------------------- |
| (20) [Image](ArtistWorkstation/20-Image.json) ([Parameters](ArtistWorkstation/20-Image.Parameters.json)) | (20) [Image](ArtistWorkstation/20-Image.json) ([Parameters](ArtistWorkstation/20-Image.Parameters.json)) |
(20) [Image Customize](ArtistWorkstation/Linux/20-Image.sh) | (20) [Image Customize](ArtistWorkstation/Windows/20-Image.ps1) |
(20) [Image Customize (Blender)](RenderFarm/Linux/18-Node.Image.Blender.sh) | (20) [Image Customize (Blender)](RenderFarm/Windows/18-Node.Image.Blender.ps1) |
(20) [Image Customize (OpenCue)](ArtistWorkstation/Linux/20-Image.OpenCue.sh) | (20) [Image Customize (OpenCue)](ArtistWorkstation/Windows/20-Image.OpenCue.ps1) |
(20) [* Image Customize (Royal Render)](ArtistWorkstation/Linux/20-Image.RoyalRender.sh) | (20) [* Image Customize (Royal Render)](ArtistWorkstation/Windows/20-Image.RoyalRender.ps1) |
(20) [Image Customize (Teradici)](ArtistWorkstation/Linux/20-Image.Teradici.sh) | (20) [Image Customize (Teradici)](ArtistWorkstation/Windows/20-Image.Teradici.ps1) |
(21) [Machine](ArtistWorkstation/21-Machine.json) ([Parameters](ArtistWorkstation/21-Machine.Parameters.json)) | (21) [Machine](ArtistWorkstation/21-Machine.json) ([Parameters](ArtistWorkstation/21-Machine.Parameters.json)) |
(21) [Machine Initialize](ArtistWorkstation/Linux/21-Machine.sh) | (21) [Machine Initialize](ArtistWorkstation/Windows/21-Machine.ps1) |

\* = TBD

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
