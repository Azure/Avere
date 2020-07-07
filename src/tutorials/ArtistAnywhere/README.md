# Azure Artist Anywhere

Azure Artist Anywhere is a modular set of parameterized [Azure Resource Manager (ARM)](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/overview) templates (JSON) for the automated deployment of an end-to-end rendering solution in Microsoft Azure. Azure Artist Anywhere provides a lightweight solution framework that can be configured and extended as needed to meet various hybrid environment requirements. Each resource deployment template can also be leveraged directly.

## Deployment Templates

Azure Artist Anywhere is composed of the following Microsoft Azure resource deployment templates.

| Virtual Network | Storage Cache | Render Managers | Render Workers | Artist Desktops |
| - | - | - | - | - |
| [00 - Network](VirtualNetwork/00-Network.json) | [03 - Storage (NetApp)](StorageCache/03-Storage.NetApp.json) | [05 - Manager Data](RenderManager/05-Manager.Data.json) | [08 - Worker Images](RenderWorker/08-Worker.Images.json) | [10 - Desktop Images](ArtistDesktop/10-Desktop.Images.json) |
| [01 - Access Control](VirtualNetwork/01-Access.Control.json) | [03 - Storage (Object)](StorageCache/03-Storage.Object.json) | [06 - Manager Images](RenderManager/06-Manager.Images.json) | [08 - Worker Images Customize Script (Linux)](RenderWorker/08-Worker.Images.sh) | [10 - Desktop Images Customize Script (Linux)](ArtistDesktop/10-Desktop.Images.sh) |
| [02 - Image Gallery](VirtualNetwork/02-Image.Gallery.json) | [04 - Cache (HPC)](StorageCache/04-Cache.json) | [06 - Manager Images Customize Script (Linux)](RenderManager/06-Manager.Images.sh) | [09 - Worker Machines](RenderWorker/09-Worker.Machines.json) | [10 - Desktop Images Customize Script (Windows)](ArtistDesktop/10-Desktop.Images.ps1) |
| | | [07 - Manager Machines](RenderManager/07-Manager.Machines.json) | [09 - Worker Machines Extension Script (Linux)](RenderWorker/09-Worker.Machines.sh) | [11 - Desktop Machines](ArtistDesktop/11-Desktop.Machines.json) |
| | | [07 - Manager Machines Extension Script (Linux)](RenderManager/07-Manager.Machines.sh) | | [11 - Desktop Machines Extension Script (Linux)](ArtistDesktop/11-Desktop.Machines.sh) |
| | | | | [11 - Desktop Machines Extension Script (Windows)](ArtistDesktop/11-Desktop.Machines.ps1) |

## Solution Architecture

Azure Artist Anywhere is composed of the following open-source software and Microsoft Azure services.

<table>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview" target="_blank">Azure Virtual Network</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview" target="_blank">Azure HPC Cache</a>
        </td>
        <td>
            <a href="https://docs.teradici.com/find/product/cloud-access-software" target="_blank">Teradici PCoIP Remote Access</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways" target="_blank">Azure Virtual Network Gateway</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction" target="_blank">Azure NetApp Files</a>
        </td>
        <td>
            <a href="https://www.blender.org/" target="_blank">Blender Artist 3D Creation Suite</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/" target="_blank">Azure Virtual Machines</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-overview" target="_blank">Azure Object (Blob) Storage</a>
        </td>
        <td>
            <a href="https://www.opencue.io/" target="_blank">OpenCue Render Farm Manager</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview" target="_blank">Azure Virtual Machine Scale Sets</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-overview" target="_blank">Azure Image Builder</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/postgresql/overview" target="_blank">Azure Database for PostgreSQL</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/dns/private-dns-overview" target="_blank">Azure Private DNS</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/linux/shared-image-galleries" target="_blank">Azure Shared Image Gallery</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview" target="_blank">Azure Load Balancer</a>
        </td>
    </tr>
    <tr>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-whatis" target="_blank">Azure Active Directory</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/key-vault/key-vault-overview" target="_blank">Azure Key Vault</a>
        </td>
        <td>
            <a href="https://docs.microsoft.com/en-us/azure/azure-monitor/" target="_blank">Azure Monitor</a>
        </td>
    </tr>
</table>

The following diagram depicts the Azure Artist Anywhere solution architecture, which spans on-premises and Microsoft Azure.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.SolutionArchitecture.2020-07-01.png)

The following diagram defines the Azure Artist Anywhere deployment modules along with their dependency relationships.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.ModuleDependency.2020-07-01.png)

The following list describes each of the Azure Artist Anywhere deployment script files.

* [*Deploy.ps1*](Deploy.ps1) - main script that orchestrates the solution deployment process

* [*Deploy.psm1*](Deploy.psm1) - shared module that is referenced from each deployment script

* [*Deploy.SharedServices.ps1*](Deploy.SharedServices.ps1) - core script that deploys shared services (Network, Storage, etc.)

* [*Deploy.RenderManager.ps1*](Deploy.RenderManager.ps1) - background job script that deploys the render farm manager services

* [*Deploy.ArtistDesktop.ps1*](Deploy.ArtistDesktop.ps1) - orchestration script that deploys the artist desktop images & machines

* [*Deploy.ArtistDesktop.Images.ps1*](Deploy.ArtistDesktop.Images.ps1) - background job script that deploys the artist desktop images

* [*Deploy.ArtistDesktop.Machines.ps1*](Deploy.ArtistDesktop.Machines.ps1) - background job script that deploys artist desktop machines

As an example deployment, the following output is from the [*Deploy.ps1*](Deploy.ps1) script within Azure Cloud Shell.

![](https://mediasolutions.blob.core.windows.net/bin/AzureArtistAnywhere.ModuleDeployment.06-01-2020.png)

For more information, contact Rick Shahid (rick.shahid@microsoft.com)
