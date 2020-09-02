# Azure Artist Anywhere ([aka.ms/aaa](http://aka.ms/aaa))

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/azure/azure-resource-manager/management/overview) templates for automated deployment of an end-to-end rendering solution architecture in Microsoft Azure. Azure Artist Anywhere provides a lightweight deployment framework that can be configured and extended as needed to meet various environment and integration requirements, including burst rendering with caching of on-premises asset storage.

## Deployment Templates

The following Microsoft Azure resource templates and customization scripts define the Azure Artist Anywhere deployment modules.

| *Studio Services* | *Image Library* | *Storage Cache* | *Render Managers* | *Render Workers* | *Artist Desktop Images* | *Artist Desktop Machines*
| - | - | - | - | - | - | - |
| [00 - Network](StudioServices/00-Network.json) | [02 - Image Gallery](ImageLibrary/02-Image.Gallery.json) | [04 - Storage Network](StorageCache/04-Storage.Network.json) | [06 - Manager Data](RenderManager/06-Manager.Data.json) | [09 - Worker Images](RenderWorker/09-Worker.Images.json) | [11 - Desktop Images](ArtistDesktop/11-Desktop.Images.json) | [12 - Desktop Machines](ArtistDesktop/12-Desktop.Machines.json)
| [01 - Security](StudioServices/01-Security.json) | [03 - Image Registry](ImageLibrary/03-Image.Registry.json) | [04 - Storage (NetApp)](StorageCache/04-Storage.NetApp.json) | [07 - Manager Images](RenderManager/07-Manager.Images.json) | [09 - Worker Images Customize](RenderWorker/09-Worker.Images.Customize.sh) | [11 - Desktop Images Customize (Linux) ](ArtistDesktop/11-Desktop.Images.Customize.sh) | [12 - Desktop Machines Initialize (Linux)](ArtistDesktop/12-Desktop.Machines.sh)
| | | [04 - Storage (Object)](StorageCache/04-Storage.Object.json) | [07 - Manager Images Customize](RenderManager/07-Manager.Images.Customize.sh) | [09 - Worker Images Customize (OpenCue)](RenderWorker/09-Worker.Images.Customize.OpenCue.sh) | [11 - Desktop Images Customize (Linux OpenCue)](ArtistDesktop/11-Desktop.Images.Customize.OpenCue.sh) | [12 - Desktop Machines Initialize (Windows)](ArtistDesktop/12-Desktop.Machines.ps1)
| | | [05 - Cache (HPC)](StorageCache/05-Cache.json) | [07 - Manager Images Customize (OpenCue)](RenderManager/07-Manager.Images.Customize.OpenCue.sh) | [09 - Worker Images Customize (Blender)](RenderWorker/09-Worker.Images.Customize.Blender.sh) | [11 - Desktop Images Customize (Linux Blender) ](ArtistDesktop/11-Desktop.Images.Customize.Blender.sh) |
| | | | [07 - Manager Images Customize (Blender)](RenderManager/07-Manager.Images.Customize.Blender.sh) | [10 - Worker Scale Sets](RenderWorker/10-Worker.ScaleSets.json) | [11 - Desktop Images Customize (Windows) ](ArtistDesktop/11-Desktop.Images.Customize.ps1) |
| | | | [08 - Manager Machines](RenderManager/08-Manager.Machines.json) | [10 - Worker Clusters (TBD)](RenderWorker/10-Worker.Clusters.json) | [11 - Desktop Images Customize (Windows OpenCue) ](ArtistDesktop/11-Desktop.Images.Customize.OpenCue.ps1) |
| | | | [08 - Manager Machines Initialize](RenderManager/08-Manager.Machines.sh) | [10 - Worker Machines Initialize](RenderWorker/10-Worker.Machines.sh) | [11 - Desktop Images Customize (Windows Blender) ](ArtistDesktop/11-Desktop.Images.Customize.Blender.ps1) |
| | | | [08 - Manager Machines Initialize (Data Access)](RenderManager/08-Manager.Machines.DataAccess.sh) | | |

## Solution Architecture

The following overview diagram depicts the Azure Artist Anywhere solution architecture with on-premises storage.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.SolutionArchitecture.2020-09-01.png)

The following Microsoft Azure services and open-source software comprise the Azure Artist Anywhere solution.

<table>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview" target="_blank">Azure Virtual Network</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction" target="_blank">Azure NetApp Files</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/private-link/private-link-overview" target="_blank">Azure Private Link</a>
        </td>
        <td>
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Farm Manager</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways" target="_blank">Azure Virtual Network Gateway</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview" target="_blank">Azure Object Storage</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/dns/private-dns-overview" target="_blank">Azure Private DNS</a>
        </td>
        <td>
            <a href="https://www.blender.org/" target="_blank">Blender Artist 3D Creation Suite</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview" target="_blank">Azure Managed Identity</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview" target="_blank">Azure HPC Cache</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/load-balancer/load-balancer-overview" target="_blank">Azure Load Balancer</a>
        </td>
        <td>
            <a href="https://docs.teradici.com/find/product/cloud-access-software" target="_blank">Teradici PCoIP Remote Access</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/key-vault/key-vault-overview" target="_blank">Azure Key Vault</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/shared-image-galleries" target="_blank">Azure Shared Image Gallery</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/postgresql/overview" target="_blank">Azure Database for PostgreSQL</a>
        </td>
        <td>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/azure-monitor/overview" target="_blank">Azure Monitor</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/container-registry/container-registry-intro" target="_blank">Azure Container Registry</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/overview" target="_blank">Azure Virtual Machines</a>
        </td>
        <td>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/azure/automation/automation-intro" target="_blank">Azure Automation</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machines/linux/image-builder-overview" target="_blank">Azure Image Builder</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview" target="_blank">Azure Virtual Machine Scale Sets</a>
        </td>
        <td>
        </td>
    </tr>
</table>

The following diagram defines the Azure Artist Anywhere deployment modules along with their dependency relationships.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.ModuleDependency.2020-08-01.png)

The following list describes each of the Azure Artist Anywhere deployment script files.

* [*Deploy.ps1*](Deploy.ps1) - main script that orchestrates the solution deployment process

* [*Deploy.psm1*](Deploy.psm1) - shared module that is referenced from each deployment script

* [*Deploy.SharedServices.ps1*](Deploy.SharedServices.ps1) - core script that deploys shared studio services

* [*Deploy.StorageCache.ps1*](Deploy.StorageCache.ps1) - background job script that deploys storage and cache services

* [*Deploy.RenderManager.ps1*](Deploy.RenderManager.ps1) - background job script that deploys the render farm manager services

* [*Deploy.ArtistDesktop.ps1*](Deploy.ArtistDesktop.ps1) - orchestration script that deploys the artist desktop images & machines

* [*Deploy.ArtistDesktop.Images.ps1*](Deploy.ArtistDesktop.Images.ps1) - background job script that deploys the artist desktop images

* [*Deploy.ArtistDesktop.Machines.ps1*](Deploy.ArtistDesktop.Machines.ps1) - background job script that deploys artist desktop machines

As an example deployment, the following output is from the [*Deploy.ps1*](Deploy.ps1) script within Azure Cloud Shell.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.ModuleDeployment.2020-08-01.png)

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
