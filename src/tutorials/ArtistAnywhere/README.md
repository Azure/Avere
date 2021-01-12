# Azure Artist Anywhere ([aka.ms/aaa](http://aka.ms/aaa))

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/azure/azure-resource-manager/management/overview) templates for automated deployment of an end-to-end rendering solution architecture in Microsoft Azure. Azure Artist Anywhere provides a lightweight and extensible deployment framework that can be configured as needed to meet various integration requirements, including burst rendering with caching of on-premises storage.

Azure Artist Anywhere provides the following mutually-exclusive render manager deployment configuration modes.

* [*OpenCue*](https://www.opencue.io) - enables [OpenCue](https://www.opencue.io) integration with the [Azure Virtual Machine Scale Set (VMSS)](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview) service

* [*VRay*](https://www.chaosgroup.com/vray) - enables [V-Ray Blender](https://www.chaosgroup.com/vray/blender) integration with the [Azure Virtual Machine Scale Set (VMSS)](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview) service

* [*CycleCloud*](https://docs.microsoft.com/azure/cyclecloud/overview) - enables [OpenCue](https://www.opencue.io) integration with the [Azure CycleCloud](https://docs.microsoft.com/azure/cyclecloud/overview) cluster management service

* [*Batch*](https://docs.microsoft.com/azure/batch/batch-technical-overview) - enables the [Azure Batch](https://docs.microsoft.com/azure/batch/batch-technical-overview) platform service, which is Azure's native HPC job scheduler service

The following sample output frame was rendered on Azure using [Blender](https://www.blender.org), which is an open-source 3D content creation suite.

![](https://mediasolutions.blob.core.windows.net/bin/Blender/classroom.png)

## Deployment Modules

The following Microsoft Azure resource templates and scripts define the Azure Artist Anywhere deployment modules.

| *Shared Framework* | *Storage Cache* | *Render Manager* |
| :----------------- | :-------------- | :--------------- |
| 00 - [Virtual Network](SharedFramework/00-VirtualNetwork.json) ([Parameters](SharedFramework/00-VirtualNetwork.Parameters.json)) | 06 - [Storage](StorageCache/06-Storage.json) ([Parameters](StorageCache/06-Storage.Parameters.json)) | 08 - [Batch Account](RenderManager/08-BatchAccount.json) ([Parameters](RenderManager/08-BatchAccount.Parameters.json)) |
| 01 - [Managed Identity](SharedFramework/01-ManagedIdentity.json) ([Parameters](SharedFramework/01-ManagedIdentity.Parameters.json)) | 06 - [Storage NetApp](StorageCache/06-Storage.NetApp.json) ([Parameters](StorageCache/06-Storage.NetApp.Parameters.json)) | 09 - [OpenCue Data](RenderManager/09-OpenCue.Data.json) ([Parameters](RenderManager/09-OpenCue.Data.Parameters.json)) |
| 02 - [Key Vault](SharedFramework/02-KeyVault.json) ([Parameters](SharedFramework/02-KeyVault.Parameters.json)) | 07 - [Cache](StorageCache/07-Cache.json) ([Parameters](StorageCache/07-Cache.Parameters.json)) | 10 - [OpenCue Image](RenderManager/10-OpenCue.Image.json) ([Parameters](RenderManager/10-OpenCue.Image.Parameters.json)) |
| 03 - [Monitor Insight](SharedFramework/03-MonitorInsight.json) ([Parameters](SharedFramework/03-MonitorInsight.Parameters.json)) | | 10 - [OpenCue Image Customize](RenderManager/10-OpenCue.Image.sh) |
| 04 - [Image Gallery](SharedFramework/04-ImageGallery.json) ([Parameters](SharedFramework/04-ImageGallery.Parameters.json)) | | 11 - [OpenCue Machine](RenderManager/11-OpenCue.Machine.json) ([Parameters](RenderManager/11-OpenCue.Machine.Parameters.json)) |
| 05 - [Container Registry](SharedFramework/05-ContainerRegistry.json) ([Parameters](SharedFramework/05-ContainerRegistry.Parameters.json)) | | 11 - [OpenCue Machine Initialize](RenderManager/11-OpenCue.Machine.sh) |
| | | 12 - [CycleCloud Machine](RenderManager/12-CycleCloud.Machine.json) ([Parameters](RenderManager/12-CycleCloud.Machine.Parameters.json)) |

| *Render Farm (Linux)* | *Render Farm (Windows)* |
| :-------------------- | :---------------------- |
| 13 - [Node Image](RenderFarm/13-Node.Image.json) ([Parameters](RenderFarm/13-Node.Image.Parameters.json)) | 13 - [Node Image](RenderFarm/13-Node.Image.json) ([Parameters](RenderFarm/13-Node.Image.Parameters.json)) |
| 13 - [Node Image Customize](RenderFarm/13-Node.Image.sh) | 13 - [Node Image Customize](RenderFarm/13-Node.Image.ps1) |
| 13 - [Node Image Customize (Blender)](RenderFarm/13-Node.Image.Blender.sh) | 13 - [Node Image Customize (Blender)](RenderFarm/13-Node.Image.Blender.ps1) |
| 13 - [Node Image Customize (OpenCue)](RenderFarm/13-Node.Image.OpenCue.sh) | 13 - [Node Image Customize (OpenCue)](RenderFarm/13-Node.Image.OpenCue.ps1) |
| 13 - [Node Image Customize (V-Ray for Maya)](RenderFarm/13-Node.Image.VRayMaya.sh) | 13 - [Node Image Customize (V-Ray for Maya)](RenderFarm/13-Node.Image.VRayMaya.ps1) |
| 14 - [Farm Pool](RenderFarm/14-Farm.Pool.json) ([Parameters](RenderFarm/14-Farm.Pool.Parameters.json)) | 14 - [Farm Pool](RenderFarm/14-Farm.Pool.json) ([Parameters](RenderFarm/14-Farm.Pool.Parameters.json)) |
| 14 - [Farm Scale Set](RenderFarm/14-Farm.ScaleSet.json) ([Parameters](RenderFarm/14-Farm.ScaleSet.Parameters.json)) | 14 - [Farm Scale Set](RenderFarm/14-Farm.ScaleSet.json) ([Parameters](RenderFarm/14-Farm.ScaleSet.Parameters.json)) |
| 14 - [Farm Scale Set Initialize](RenderFarm/14-Farm.ScaleSet.sh) | 14 - [Farm Scale Set Initialize](RenderFarm/14-Farm.ScaleSet.ps1) |



| *Artist Workstation Image* | *Artist Workstation Machine* |
| :------------------------- | :--------------------------- |
| 15 - [Workstation Image Template](ArtistWorkstation/15-Linux.Workstation.Image.json) ([Linux Parameters](ArtistWorkstation/15-Linux.Workstation.Image.Parameters.json), [Windows Parameters](ArtistWorkstation/15-Windows.Workstation.Image.Parameters.json)) | 16 - [Workstation Machine](ArtistWorkstation/16-Linux.Workstation.Machine.json) ([Linux Parameters](ArtistWorkstation/16-Linux.Workstation.Machine.Parameters.json), [Windows Parameters](ArtistWorkstation/16-Windows.Workstation.Machine.Parameters.json)) |
| 15 - [Linux Workstation Image Customize](ArtistWorkstation/15-Linux.Workstation.Image.sh) ([Blender](RenderFarm/13-Node.Image.Blender.sh), [OpenCue](ArtistWorkstation/15-Linux.Workstation.Image.OpenCue.sh), [Teradici](ArtistWorkstation/15-Linux.Workstation.Image.Teradici.sh)) | 16 - [Linux Workstation Machine Initialize](ArtistWorkstation/16-Linux.Workstation.Machine.sh) |
| 15 - [Windows Workstation Image Customize](ArtistWorkstation/15-Windows.Workstation.Image.ps1) ([Blender](ArtistWorkstation/15-Windows.Workstation.Image.Blender.ps1), [OpenCue](ArtistWorkstation/15-Windows.Workstation.Image.OpenCue.ps1), [Teradici](ArtistWorkstation/15-Windows.Workstation.Image.Teradici.ps1)) | 16 - [Windows Workstation Machine Initialize](ArtistWorkstation/16-Windows.Workstation.Machine.ps1) |

<!-- | *Stream Edge* |
| :------------ |
| 17 - [Remote Render](StreamEdge/17-RemoteRender.json) ([Parameters](StreamEdge/17-RemoteRender.Parameters.json)) |
| 18 - [Media Services](StreamEdge/18-MediaServices.json) ([Parameters](StreamEdge/18-MediaServices.Parameters.json)) | -->

## Solution Architecture

The following overview diagram depicts the Azure Artist Anywhere solution architecture with on-premises storage.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.SolutionArchitecture.2020-12-01.png)

The following Microsoft Azure services and open-source software comprise the Azure Artist Anywhere solution.

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
            <a href="https://docs.microsoft.com/azure/cyclecloud/overview" target="_blank">Azure CycleCloud</a>
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
            <a href="https://docs.microsoft.com/azure/event-grid/overview" target="_blank">Azure Event Grid</a>
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
            <a href="https://docs.microsoft.com/azure/bastion/bastion-overview" target="_blank">Azure Bastian</a>
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
            <a href="https://docs.microsoft.com/azure/postgresql/overview" target="_blank">Azure Database for PostgreSQL</a>
        </td>
        <td>
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Manager</a>
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
            <a href="https://www.blender.org/" target="_blank">Blender 3D Content Creation</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/automation/automation-intro" target="_blank">Azure Automation</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview" target="_blank">Azure Virtual Machine Scale Sets</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/batch/batch-technical-overview" target="_blank">Azure Batch</a>
        </td>
        <td>
            <a href="https://docs.teradici.com/find/product/cloud-access-software" target="_blank">Teradici PCoIP Remote Access</a>
        </td>
    </tr>
</table>

The following diagram defines the Azure Artist Anywhere deployment modules along with their dependency relationships.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.ModuleDependency.2020-12-01.png)

As an example deployment, the following output is from the [*Deploy.ps1*](Deploy.ps1) script within Azure Cloud Shell.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.ModuleDeployment.2020-08-01.png)

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
