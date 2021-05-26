# Azure Artist Anywhere ([aka.ms/aaa](https://aka.ms/aaa))

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/azure/azure-resource-manager/management/overview) templates for automated deployment of an end-to-end rendering solution in Microsoft Azure. Azure Artist Anywhere provides a lightweight and customizable deployment framework with the storage tier in Azure and/or asset storage located on-premises with Azure compute integration via the [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) managed service.

As a simple example, the following 3D image was rendered via [Azure HPC Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-hpc) in an [Azure Virtual Machine Scale Set (VMSS)](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview).

![](https://bit1.blob.core.windows.net/doc/AzureArtistAnywhere/SuspensionBridge.jpg)

## Solution Architecture

The following overview diagram depicts the Azure Artist Anywhere solution architecture, including on-premises storage asset caching.

![](https://bit1.blob.core.windows.net/doc/AzureArtistAnywhere/SolutionArchitecture.png)

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
            <a href="https://www.blender.org/" target="_blank">Blender Content Creation Suite</a>
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
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Management</a>
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
            <a href="https://royalrender.de/" target="_blank">Royal Render Management</a>
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

The following Microsoft Azure resource templates and scripts define the Azure Artist Anywhere deployment modules. For individual and self-contained module deployment automation, refer to the [Resource Manager](ResourceManager) folder.

| *Base Framework* | *Storage Cache* | *Event Handler* | *Image Library* |
| :--------------- | :-------------- | :-------------- | :-------------- |
| (01) [Virtual Network](BaseFramework/01-VirtualNetwork.json) ([Parameters](BaseFramework/01-VirtualNetwork.Parameters.json)) | (06) [Storage](StorageCache/06-Storage.json) ([Parameters](StorageCache/06-Storage.Parameters.json)) | (08) [* Event Grid](EventHandler/08-EventGrid.json) ([Parameters](EventHandler/08-EventGrid.Parameters.json)) | (10) [Image Gallery](ImageLibrary/10-ImageGallery.json) ([Parameters](ImageLibrary/10-ImageGallery.Parameters.json)) |
| (02) [Monitor Insights](BaseFramework/02-MonitorInsights.json) ([Parameters](BaseFramework/02-MonitorInsights.Parameters.json)) | (06) [Storage NetApp](StorageCache/06-Storage.NetApp.json) ([Parameters](StorageCache/06-Storage.NetApp.Parameters.json)) | (09) [* Function App](EventHandler/09-FunctionApp.json) ([Parameters](EventHandler/09-FunctionApp.Parameters.json)) | (11) [Container Registry](ImageLibrary/11-ContainerRegistry.json) ([Parameters](ImageLibrary/11-ContainerRegistry.Parameters.json)) |
| (03) [Managed Identity](BaseFramework/03-ManagedIdentity.json) ([Parameters](BaseFramework/03-ManagedIdentity.Parameters.json)) | (06) [* Storage Qumulo](StorageCache/06-Storage.Qumulo.json) ([Parameters](StorageCache/06-Storage.Qumulo.Parameters.json)) | | |
| (04) [Key Vault](BaseFramework/04-KeyVault.json) ([Parameters](BaseFramework/04-KeyVault.Parameters.json)) | (06) [* Storage Hammerspace](StorageCache/06-Storage.Hammerspace.json) ([Parameters](StorageCache/06-Storage.Hammerspace.Parameters.json)) | | |
| (05) [Network Gateway](BaseFramework/05-NetworkGateway.json) ([Parameters](BaseFramework/05-NetworkGateway.Parameters.json)) | (07) [HPC Cache](StorageCache/07-HPCCache.json) ([Parameters](StorageCache/07-HPCCache.Parameters.json)) |


\* = TBD

| *Render Manager (Linux)* | *Render Manager (Windows)* |
| :----------------------- | :------------------------- |
| (12) [Database](RenderManager/12-Database.json) ([Parameters](RenderManager/12-Database.Parameters.json)) | (12) [Database](RenderManager/12-Database.json) ([Parameters](RenderManager/12-Database.Parameters.json)) |
| (13) [Image](RenderManager/13-Image.json) ([Parameters](RenderManager/13-Image.Parameters.json)) | (13) [Image](RenderManager/13-Image.json) ([Parameters](RenderManager/13-Image.Parameters.json)) |
| (13) [Image Customize (OpenCue)](RenderManager/Linux/13-Image.OpenCue.sh) | (13) [* Image Customize (OpenCue)](RenderManager/Windows/13-Image.OpenCue.ps1) |
| (13) [* Image Customize (Royal Render)](RenderManager/Linux/13-Image.RoyalRender.sh) | (13) [* Image Customize (Royal Render)](RenderManager/Windows/13-Image.RoyalRender.ps1) |
| (14) [Machine](RenderManager/14-Machine.json) ([Parameters](RenderManager/14-Machine.Parameters.json)) | (14) [Machine](RenderManager/14-Machine.json) ([Parameters](RenderManager/14-Machine.Parameters.json)) |
| (14) [Machine Initialize](RenderManager/Linux/14-Machine.sh) | (14) [Machine Initialize](RenderManager/Windows/14-Machine.ps1) |
| (15) [CycleCloud](RenderManager/15-CycleCloud.json) ([Parameters](RenderManager/15-CycleCloud.Parameters.json)) | (15) [CycleCloud](RenderManager/15-CycleCloud.json) ([Parameters](RenderManager/15-CycleCloud.Parameters.json)) |

\* = TBD

| *Render Farm (Linux)* | *Render Farm (Windows)* |
| :-------------------- | :---------------------- |
| (16) [Node Image](RenderFarm/16-NodeImage.json) ([Parameters](RenderFarm/16-NodeImage.Parameters.json)) | (16) [Node Image](RenderFarm/16-NodeImage.json) ([Parameters](RenderFarm/16-NodeImage.Parameters.json)) |
| (16) [Node Image Customize](RenderFarm/Linux/16-NodeImage.sh) | (16) [Node Image Customize](RenderFarm/Windows/16-NodeImage.ps1) |
| (16) [Node Image Customize (Blender)](RenderFarm/Linux/16-NodeImage.Blender.sh) | (16) [Node Image Customize (Blender)](RenderFarm/Windows/16-NodeImage.Blender.ps1) |
| (16) [Node Image Customize (OpenCue)](RenderFarm/Linux/16-NodeImage.OpenCue.sh) | (16) [Node Image Customize (OpenCue)](RenderFarm/Windows/16-NodeImage.OpenCue.ps1) |
| (16) [* Node Image Customize (Royal Render)](RenderFarm/Linux/16-NodeImage.RoyalRender.sh) | (16) [* Node Image Customize (RoyalRender)](RenderFarm/Windows/16-NodeImage.RoyalRender.ps1) |
| (17) [Scale Set](RenderFarm/17-ScaleSet.json) ([Parameters](RenderFarm/17-ScaleSet.Parameters.json)) | (17) [Scale Set](RenderFarm/17-ScaleSet.json) ([Parameters](RenderFarm/17-ScaleSet.Parameters.json)) |
| (17) [Scale Set Initialize](RenderFarm/Linux/17-ScaleSet.sh) | (17) [Farm Scale Set Initialize](RenderFarm/Windows/17-ScaleSet.ps1) |

\* = TBD

| *Artist Workstation (Linux)* | *Artist Workstation (Windows)* |
| :--------------------------- | :----------------------------- |
| (18) [Image](ArtistWorkstation/18-Image.json) ([Parameters](ArtistWorkstation/18-Image.Parameters.json)) | (18) [Image](ArtistWorkstation/18-Image.json) ([Parameters](ArtistWorkstation/18-Image.Parameters.json)) |
(18) [Image Customize](ArtistWorkstation/Linux/18-Image.sh) | (18) [Image Customize](ArtistWorkstation/Windows/18-Image.ps1) |
(18) [Image Customize (Blender)](RenderFarm/Linux/16-NodeImage.Blender.sh) | (18) [Image Customize (Blender)](RenderFarm/Windows/16-NodeImage.Blender.ps1) |
(18) [Image Customize (OpenCue)](ArtistWorkstation/Linux/18-Image.OpenCue.sh) | (18) [Image Customize (OpenCue)](ArtistWorkstation/Windows/18-Image.OpenCue.ps1) |
(18) [* Image Customize (Royal Render)](ArtistWorkstation/Linux/18-Image.RoyalRender.sh) | (18) [* Image Customize (Royal Render)](ArtistWorkstation/Windows/18-Image.RoyalRender.ps1) |
(18) [Image Customize (Teradici)](ArtistWorkstation/Linux/18-Image.Teradici.sh) | (18) [Image Customize (Teradici)](ArtistWorkstation/Windows/18-Image.Teradici.ps1) |
(19) [Machine](ArtistWorkstation/19-Machine.json) ([Parameters](ArtistWorkstation/19-Machine.Parameters.json)) | (19) [Machine](ArtistWorkstation/19-Machine.json) ([Parameters](ArtistWorkstation/19-Machine.Parameters.json)) |
(19) [Machine Initialize](ArtistWorkstation/Linux/19-Machine.sh) | (19) [Machine Initialize](ArtistWorkstation/Windows/19-Machine.ps1) |

\* = TBD

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
