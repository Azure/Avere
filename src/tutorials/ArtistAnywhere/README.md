# Azure Artist Anywhere ([aka.ms/aaa](https://aka.ms/aaa))

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/azure/azure-resource-manager/management/overview) templates for the automated deployment of an end-to-end rendering solution in Microsoft Azure. Azure Artist Anywhere provides a lightweight and customizable deployment framework with the asset storage tier located in Azure and/or on-premises with Azure render farm compute integration via the [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) managed service.

As a simple example, the following image was rendered in Azure via [Azure HPC Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-hpc) in an [Azure Virtual Machine Scale Set (VMSS)](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview).

<!-- markdown-link-check-disable-next-line -->
![](https://bit1.blob.core.windows.net/doc/AzureArtistAnywhere/SuspensionBridge.jpg?sv=2020-04-08&st=2021-05-29T22%3A07%3A54Z&se=2222-05-30T22%3A07%3A00Z&sr=c&sp=rl&sig=0BEFPK7gDh3D57FW6FTdOb8l6bISbtjPBUm3asmzGQs%3D)

## Solution Architecture

The following overview diagram depicts the Azure Artist Anywhere solution architecture, including multiple options for asset storage.

<!-- markdown-link-check-disable-next-line -->
![](https://bit1.blob.core.windows.net/doc/AzureArtistAnywhere/SolutionArchitecture.png?sv=2020-04-08&st=2021-05-29T22%3A07%3A54Z&se=2222-05-30T22%3A07%3A00Z&sr=c&sp=rl&sig=0BEFPK7gDh3D57FW6FTdOb8l6bISbtjPBUm3asmzGQs%3D)

The integration of the following Microsoft Azure services and 3rd-party software enables the Azure Artist Anywhere rendering solution.

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
            <a href="https://docs.microsoft.com/azure/virtual-machines" target="_blank">Azure Virtual Machines</a><br/>(<a href="https://docs.microsoft.com/azure/virtual-machines/linux/overview" target="_blank">Linux</a>, <a href="https://docs.microsoft.com/azure/virtual-machines/windows/overview" target="_blank">Windows</a>)
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview" target="_blank">Azure HPC Cache</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways" target="_blank">Azure Virtual Network Gateway</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/postgresql/overview" target="_blank">Azure Database for PostgreSQL</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview" target="_blank">Azure Virtual Machine Scale Sets</a>
        </td>
        <td>
            <a href="https://www.blender.org/" target="_blank">Blender Content Creation</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview" target="_blank">Azure Managed Identity</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-overview" target="_blank">Azure Image Builder</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/private-link/private-link-overview" target="_blank">Azure Private Link</a> / <a href="https://docs.microsoft.com/azure/dns/private-dns-overview" target="_blank">DNS</a>
        </td>
        <td>
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Management</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/key-vault/key-vault-overview" target="_blank">Azure Key Vault</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries" target="_blank">Azure Shared Image Gallery</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/azure-monitor/overview" target="_blank">Azure Monitor</a> / <a href="https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview" target="_blank">App Insights</a>
        </td>
        <td>
            <a href="https://docs.teradici.com/find/product/cloud-access-software" target="_blank">Teradici Remote Access (PCoIP)</a>
        </td>
    </tr>
</table>

## Deployment Modules

Azure Artist Anywhere is composed from the following Microsoft Azure resource templates and deployment scripts.

| *Base Framework* | *Storage Cache* | *Image Library* |
| :--------------- | :-------------- | :-------------- |
| (00) [Monitor Telemetry](BaseFramework/00.MonitorTelemetry.json) ([Parameters](BaseFramework/00.MonitorTelemetry.Parameters.json)) | (05) [Storage](StorageCache/05.Storage.json) ([Parameters](StorageCache/05.Storage.Parameters.json)) | (07) [Image Gallery](ImageLibrary/07.ImageGallery.json) ([Parameters](ImageLibrary/07.ImageGallery.Parameters.json))
| (01) [Virtual Network](BaseFramework/01.VirtualNetwork.json) ([Parameters](BaseFramework/01.VirtualNetwork.Parameters.json)) | (06) [HPC Cache](StorageCache/06.HPCCache.json) ([Parameters](StorageCache/06.HPCCache.Parameters.json)) | (08) [Container Registry](ImageLibrary/08.ContainerRegistry.json) ([Parameters](ImageLibrary/08.ContainerRegistry.Parameters.json))
| (02) [Managed Identity](BaseFramework/02.ManagedIdentity.json) ([Parameters](BaseFramework/02.ManagedIdentity.Parameters.json)) | (06) [HPC Cache DNS](StorageCache/06.HPCCache.DNS.json) ([Parameters](StorageCache/06.HPCCache.DNS.Parameters.json)) |
| (03) [Key Vault](BaseFramework/03.KeyVault.json) ([Parameters](BaseFramework/03.KeyVault.Parameters.json)) | |
| (04) [Network Gateway](BaseFramework/04.NetworkGateway.json) ([Parameters](BaseFramework/04.NetworkGateway.Parameters.json)) | |

| *Render Manager (Linux)* | *Render Manager (Windows)* |
| :----------------------- | :------------------------- |
| (09) [Database](RenderManager/09.Database.json) ([Parameters](RenderManager/09.Database.Parameters.json)) | (09) [Database](RenderManager/09.Database.json) ([Parameters](RenderManager/09.Database.Parameters.json)) |
| (10) [Image](RenderManager/10.Image.json) ([Parameters](RenderManager/10.Image.Parameters.json)) | (10) [Image](RenderManager/10.Image.json) ([Parameters](RenderManager/10.Image.Parameters.json)) |
| (10) [Image Customize](RenderManager/Linux/10.Image.sh) | (10) [Image Customize](RenderManager/Windows/10.Image.ps1) |
| (11) [Machine](RenderManager/11.Machine.json) ([Parameters](RenderManager/11.Machine.Parameters.json)) | (11) [Machine](RenderManager/11.Machine.json) ([Parameters](RenderManager/11.Machine.Parameters.json)) |
| (11) [Machine Initialize](RenderManager/Linux/11.Machine.sh) | (11) [Machine Initialize](RenderManager/Windows/11.Machine.ps1) |

| *Render Farm (Linux)* | *Render Farm (Windows)* |
| :-------------------- | :---------------------- |
| (12) [Image](RenderFarm/12.Image.json) ([Parameters](RenderFarm/12.Image.Parameters.json)) | (12) [Image](RenderFarm/12.Image.json) ([Parameters](RenderFarm/12.Image.Parameters.json)) |
| (12) [Image Customize](RenderFarm/Linux/12.Image.sh) | (12) [Image Customize](RenderFarm/Windows/12.Image.ps1) |
| (12) [Image Customize (Blender)](RenderFarm/Linux/12.Image.Blender.sh) | (12) [Image Customize (Blender)](RenderFarm/Windows/12.Image.Blender.ps1) |
| (12) [Image Customize (OpenCue)](RenderFarm/Linux/12.Image.OpenCue.sh) | (12) [Image Customize (OpenCue)](RenderFarm/Windows/12.Image.OpenCue.ps1) |
| (13) [Scale Set](RenderFarm/13.ScaleSet.json) ([Parameters](RenderFarm/13.ScaleSet.Parameters.json)) | (13) [Scale Set](RenderFarm/13.ScaleSet.json) ([Parameters](RenderFarm/13.ScaleSet.Parameters.json)) |
| (13) [Machine Initialize](RenderFarm/Linux/13.Machine.sh) | (13) [Machine Initialize](RenderFarm/Windows/13.Machine.ps1) |

| *Artist Workstation (Linux)* | *Artist Workstation (Windows)* |
| :--------------------------- | :----------------------------- |
| (14) [Image](ArtistWorkstation/14.Image.json) ([Parameters](ArtistWorkstation/14.Image.Parameters.json)) | (14) [Image](ArtistWorkstation/14.Image.json) ([Parameters](ArtistWorkstation/14.Image.Parameters.json)) |
(14) [Image Customize](ArtistWorkstation/Linux/14.Image.sh) | (14) [Image Customize](ArtistWorkstation/Windows/14.Image.ps1) |
(14) [Image Customize (Blender)](RenderFarm/Linux/12.Image.Blender.sh) | (14) [Image Customize (Blender)](RenderFarm/Windows/12.Image.Blender.ps1) |
(14) [Image Customize (OpenCue)](ArtistWorkstation/Linux/14.Image.OpenCue.sh) | (14) [Image Customize (OpenCue)](ArtistWorkstation/Windows/14.Image.OpenCue.ps1) |
(14) [Image Customize (Teradici)](ArtistWorkstation/Linux/14.Image.Teradici.sh) | (14) [Image Customize (Teradici)](ArtistWorkstation/Windows/14.Image.Teradici.ps1) |
(15) [Machine](ArtistWorkstation/15.Machine.json) ([Parameters](ArtistWorkstation/15.Machine.Parameters.json)) | (15) [Machine](ArtistWorkstation/15.Machine.json) ([Parameters](ArtistWorkstation/15.Machine.Parameters.json)) |
(15) [Machine Initialize](ArtistWorkstation/Linux/15.Machine.sh) | (15) [Machine Initialize](ArtistWorkstation/Windows/15.Machine.ps1) |

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
