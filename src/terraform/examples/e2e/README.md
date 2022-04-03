# Azure Artist Anywhere (AAA) Solution Deployment Framework

AAA is a *modular framework* for the *automated deployment* of the [Azure rendering solution architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). By extending your content creation pipeline with [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview), you can [globally enable](https://azure.microsoft.com/en-us/global-infrastructure/geographies) remote artists with render farm compute scale across any [Azure virtual machine size](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

The following *core principles* are implemented throughout the AAA solution deployment framework.
* Integration of security best practices, including [Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview), [Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview).
* Separation of module deployment configuration files (*config.auto.tfvars*) and code files (*main.tf*).
* Any software (render manager, renderers, etc) in a [Compute Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries) custom image is supported.

| **Module Name** | **Module Description** | **Required for<br>Compute Burst?** | **Required for<br>All Cloud?** |
| --------------- | ---------------------- | ---------------------------------- | ------------------------------ |
| [00 Global](#00-global) | Defines global variables and Terraform backend configuration for the solution. | Yes | Yes |
| [01 Security](#01-security) | Deploys [Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview) and [Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) for Terraform state files. | Yes | Yes |
| [02 Network](#02-network) | Deploys [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) with [VPN](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways) hybrid networking services. | Yes, if [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) not deployed. Otherwise, No | Yes, if [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) not deployed. Otherwise, No |
| [03 Storage](#03-storage) | Deploys [Storage Account](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview) with native NFS support and sample asset files uploaded. | No | Yes |
| [04 Storage Cache](#04-storage-cache) | Deploys [HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) for highly-available and scalable file caching. | Yes | Maybe, depends on your<br>render scale requirements |
| [05 Compute Image](#05-compute-image) | Deploys [Compute Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries) images that are built via the managed [Image Builder](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview) service. | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/07.compute.farm/config.auto.tfvars#L7) | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/07.compute.farm/config.auto.tfvars#L7) |
| [06 Compute Scheduler](#06-compute-scheduler) | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines) for job and task scheduling across render farms. | No, continue to use your current job scheduler | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/06.compute.scheduler/config.auto.tfvars#L7) |
| [07 Compute Farm](#07-compute-farm) | Deploys [Virtual Machine Scale Sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview) for [Linux](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) and/or [Windows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) render farms. | Yes | Yes |
| [08&#160;Compute&#160;Workstation](#08-compute-workstation) | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines) for [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) remote artist workstations. | No | Yes |
| [09 Monitor](#09-monitor) | Deploys [Monitor Private Link](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security) with [Private DNS](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) and [Private Endpoint](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview) integration. | No | No |
| [10 Render](#10-render) | Submit render farm jobs from [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) remote artist workstations. | No | No |

For example, the following sample output assets were rendering in Azure via the AAA solution deployment framework.
<p align="center">
  <img src="10.render/sprite-fright.png" alt="Sprite Fright" width="1024" />
</p>
<p align="center">
  <img src="10.render/moana-island.png" alt="Moana Island" width="1024" />
</p>

## Deployment Prerequisites

To manage deployment of the AAA solution from your local workstation, the following prerequisite setup steps are required.
1. Make sure the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) is installed locally and accessible in your path environment variable.
1. Make sure the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli) is installed locally and accessible in your path environment variable.
1. Download the AAA end-to-end (e2e) solution source files via the following GitHub directory link.
   * https://downgit.github.io/#/home?url=https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e
   * Unzip the downloaded `e2e.zip` file to your local home directory (`~/`).<br>Note that all local source file references below are relative to `~/e2e/`
1. Run `az account show` to ensure your current Azure subscription session context is set as expected. Verify the `id` property.<br>To change your current Azure subscription session context, run `az account set --subscription <subscriptionId>`

## 00 Global

### Configuration Steps

1. Run `cd ~/e2e/00.global` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `variables.tf` for your deployment
1. Review and edit the config values in `backend.config` for your deployment

## 01 Security

*Before deploying the Security module*, the following built-in [Azure Role-Based Access Control (RBAC)](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview) role *is required for the current user* to enable creation of Azure Key Vault secrets, certificates and keys.
* *Key Vault Administartor* (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-administrator)

For Azure role assignment instructions, refer to either the Azure [portal](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal), [CLI](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli) or [PowerShell](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell) documents.

### Deployment Steps

1. Run `cd ~/e2e/01.security` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)
1. Use the [Azure portal to update your Key Vault secret values](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal) (`GatewayConnection`, `AdminPassword`)

## 02 Network

### Deployment Steps

1. Run `cd ~/e2e/02.network` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 03 Storage

### Deployment Steps

1. Run `cd ~/e2e/03.storage` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 04 Storage Cache

*If you intend to deploy the Avere vFXT cache instead of HPC Cache, the [Terraform Avere provider](https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere) must be downloaded to your local workstation via the following commands before the cache is deployed.*

### Linux / Bash

<p><code>
latestVersion=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name)
</code></p>
<p><code>
downloadUrl=https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere
</code></p>
<p><code>
localDirectory=~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/${latestVersion:1}/linux_amd64
</code></p>
<p><code>
mkdir -p $localDirectory
</code></p>
<p><code>
cd $localDirectory
</code></p>
<p><code>
curl -o terraform-provider-avere_$latestVersion -L $downloadUrl
</code></p>
<p><code>
chmod 755 terraform-provider-avere_$latestVersion
</code></p>
<p><code>
cd ~/
</code></p>

### Windows / PowerShell

<p><code>
$latestVersion = (Invoke-WebRequest -Uri https://api.github.com/repos/Azure/Avere/releases/latest | ConvertFrom-Json).tag_name
</code></p>
<p><code>
$downloadUrl = "https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere.exe"
</code></p>
<p><code>
$localDirectory = "$Env:AppData\terraform.d\plugins\registry.terraform.io\hashicorp\avere\$($latestVersion.Substring(1))\windows_amd64"
</code></p>
<p><code>
New-Item -ItemType Directory -Path $localDirectory -Force
</code></p>
<p><code>
Set-Location $localDirectory
</code></p>
<p><code>
Invoke-WebRequest $downloadUrl -OutFile terraform-provider-avere_$latestVersion.exe
</code></p>
<p><code>
Set-Location ~/
</code></p>

### Deployment Steps

1. Run `cd ~/e2e/04.storage.cache` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. For [Avere vFXT](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) deployment only,
   * Make sure the [Avere vFXT image terms have been accepted](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms) (only required once per Azure subscription)
   * Make sure you have at least 96 (32 x 3) cores quota available for [Esv3](https://docs.microsoft.com/en-us/azure/virtual-machines/ev3-esv3-series#esv3-series) machines in your Azure subscription.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 05 Compute Image

### Deployment Steps

1. Run `cd ~/e2e/05.compute.image` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment. Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)
1. After image template deployment, use the Azure portal or [Image Builder CLI](https://docs.microsoft.com/en-us/cli/azure/image/builder?#az-image-builder-run) to start image build runs

## 06 Compute Scheduler

### Deployment Steps

1. Run `cd ~/e2e/06.compute.scheduler` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **imageId** config references the correct custom image in your Azure subscription.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 07 Compute Farm

### Deployment Steps

1. Run `cd ~/e2e/07.compute.farm` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the **imageId** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystemMounts** config has the correct values (e.g., storage account name).
       * If your config includes cache mounting, which is the default config, make sure [04 Storage Cache](#04-storage-cache) is deployed and *running* before deploying this module.
   * Make sure the **fileSystemPermissions** config has the appropriate value for your environment.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 08 Compute Workstation

### Deployment Steps

1. Run `cd ~/e2e/08.compute.workstation` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **imageId** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystemMounts** config has the correct values (e.g., storage cache mount).
       * If your config includes cache mounting, which is the default config, make sure [04 Storage Cache](#04-storage-cache) is deployed and *running* before deploying this module.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 09 Monitor

### Deployment Steps

1. Run `cd ~/e2e/09.monitor` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../00.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 10 Render

Now that deployment of the AAA solution framework is complete, this section provides render job submission examples via the general-purpose **Deadline** [SubmitCommandLineJob](https://docs.thinkboxsoftware.com/products/deadline/10.1/1_User%20Manual/manual/command-line-arguments-jobs.html#submitcommandlinejob) API.

### 10.1 [Blender](https://www.blender.org)

For example, the following sample **Blender** output asset was rendering in Azure via the **Deadline** job submission command below.
<p align="center">
  <img src="10.render/sprite-fright.png" alt="Sprite Fright" width="1024" />
</p>

#### Linux Render Farm
*The following job command can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name Sprite-Fright -executable blender -arguments "-b -y -noaudio /mnt/show/read/blender/3.0/splash.blend --render-output /mnt/show/write/blender/3.0/splash####.png --render-frame 1"
</code></p>

#### Windows Render Farm
*The following job command can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name Sprite-Fright -executable blender.exe -arguments "-b -y -noaudio R:\blender\3.0\splash.blend --render-output W:\blender\3.0\splash####.png --render-frame 1"
</code></p>

### 10.2 [Physically-Based Rendering Toolkit (PBRT)](https://pbrt.org)

For example, the following sample **PBRT** output asset was rendering in Azure via the **Deadline** job submission command below.
<p align="center">
  <img src="10.render/moana-island.png" alt="Moana Island" width="1024" />
</p>

#### Linux Render Farm
*The following job command can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name Moana-Island -executable pbrt -arguments "--outfile /mnt/show/write/pbrt/moana/island.png /mnt/show/read/pbrt/moana/pbrt/island.pbrt"
</code></p>

#### Windows Render Farm
*The following job command can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name Moana-Island -executable pbrt.exe -arguments "--outfile W:\pbrt\moana\island.png R:\pbrt\moana\pbrt\island.pbrt"
</code></p>

If you have any questions or issues, please contact rick.shahid@microsoft.com
