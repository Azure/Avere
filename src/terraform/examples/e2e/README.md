# Azure Artist Anywhere (AAA) Solution Deployment Framework

AAA is a *modular and customizable [infrastructure-as-code](https://docs.microsoft.com/devops/deliver/what-is-infrastructure-as-code) framework* for *automated deployment* of the [Azure rendering solution architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). By securely extending your content creation pipeline via the [Azure HPC Cache](https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) managed service, you can [globally enable](https://azure.microsoft.com/global-infrastructure/geographies) remote artists with highly scalable render farm compute using any [Azure virtual machine size](https://docs.microsoft.com/azure/virtual-machines/sizes), including [Azure HPC Virtual Machines](https://docs.microsoft.com/azure/virtual-machines/sizes-hpc) and [Azure GPU Virtual Machines](https://docs.microsoft.com/azure/virtual-machines/sizes-gpu).

The following *core principles* are implemented throughout the AAA solution deployment framework.
* Integration of security best practices, including [Managed Identity](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/azure/key-vault/general/overview), [Private Endpoints](https://docs.microsoft.com/azure/private-link/private-endpoint-overview).
* Any software (render manager, renderer, etc) in a [Compute Gallery](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries) custom image is supported.
* Separation of module deployment configuration files (*config.auto.tfvars*) and code files (*main.tf*).

| **Module Name** | **Module Description** | **Required for<br>Compute Burst?** | **Required for<br>All Cloud?** |
| --------------- | ---------------------- | ---------------------------------- | ------------------------------ |
| [0 Global](#0-global) | Define global variables (e.g., region name) and Terraform backend state file storage config. | Yes | Yes |
| [1 Security](#1-security) | Deploy [Managed Identity](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/azure/key-vault/general/overview) and [Blob Storage](https://docs.microsoft.com/azure/storage/blobs/storage-blobs-introduction) for Terraform state file management. | Yes | Yes |
| [2 Network](#2-network) | Deploy [Virtual Network](https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) with [VPN](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://docs.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) hybrid networking services. | Yes, if [Virtual Network](https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) not deployed. Otherwise, No | Yes, if [Virtual Network](https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview) not deployed. Otherwise, No |
| [3 Storage](#3-storage) | Deploy [Blob (NFS v3 with sample content)](https://docs.microsoft.com/azure/storage/blobs/network-file-system-protocol-support), [Files](https://docs.microsoft.com/azure/storage/files/storage-files-introduction), [NetApp Files](https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) or [Hammerspace](https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) storage. | No | Yes |
| [4 Storage Cache](#4-storage-cache) | Deploy [HPC Cache](https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://docs.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) for highly-available and scalable file caching. | Yes | Maybe, depends on your<br>render scale requirements |
| [5 Compute Image](#5-compute-image) | Deploy [Compute Gallery](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries) images that are built via the managed [Image Builder](https://docs.microsoft.com/azure/virtual-machines/image-builder-overview) service. | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/7.compute.farm/config.auto.tfvars#L7) | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/7.compute.farm/config.auto.tfvars#L7) |
| [6 Compute Scheduler](#6-compute-scheduler) | Deploy [Virtual Machines](https://docs.microsoft.com/azure/virtual-machines) for job scheduling with optional [CycleCloud](https://docs.microsoft.com/azure/cyclecloud/overview) integration. | No, continue to use your current job scheduler | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.compute.scheduler/config.auto.tfvars#L7) |
| [7 Compute Farm](#7-compute-farm) | Deploy [Virtual Machine Scale Sets](https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview) for [Linux](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) and/or [Windows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) render farms. | Yes | Yes |
| [8&#160;Compute&#160;Workstation](#8-compute-workstation) | Deploy [Virtual Machines](https://docs.microsoft.com/azure/virtual-machines) for [Linux](https://docs.microsoft.com/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | Yes |
| [9 GitOps](#9-gitops) | Enable [Terraform Plan](https://www.terraform.io/cli/commands/plan) and [Apply](https://www.terraform.io/cli/commands/apply) workflows via [GitHub Actions](https://docs.github.com/actions) triggered by [Pull Requests](https://docs.github.com/pull-requests). | No | No |
| [10 Render](#10-render) | Submit render farm jobs from [Linux](https://docs.microsoft.com/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | No |

For example, the following sample output images were rendering in Azure via the AAA solution deployment framework.

[Sprite Fright](#sprite-fright)
<p align="center">
  <img src=".github/sprite-fright.png" alt="Sprite Fright" width="1024" />
</p>

[White Lands](#white-lands)
<p align="center">
  <img src=".github/white-lands.png" alt="White Lands" width="1024" />
</p>

[Moana Island](#moana-island)
<p align="center">
  <img src=".github/moana-island.png" alt="Moana Island" width="1024" />
</p>

## Deployment Prerequisites

To manage deployment of the AAA solution from your local workstation, the following prerequisite setup steps are required. As an alternative deployment management approach, [GitOps](#9-gitops) enablement is also provided. 
1. Make sure the [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) is installed locally and accessible in your path environment variable.
1. Make sure the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli) is installed locally and accessible in your path environment variable.
1. Download the AAA end-to-end (e2e) solution source files via the following GitHub download link.
   * https://downgit.github.io/#/home?url=https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e
   * Unzip the downloaded `e2e.zip` file to your local home directory (`~/`).<br>Note that all local source file references below are relative to `~/e2e/`
1. Run `az account show` to ensure your current Azure subscription session context is set as expected. Verify the `id` property.<br>To change your current Azure subscription session context, run `az account set --subscription <subscriptionId>`

## 0 Global

### Configuration Steps

1. Run `cd ~/e2e/0.global` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `variables.tf` for your deployment
1. Review and edit the config values in `backend.config` for your deployment

## 1 Security

*Before deploying the Security module*, the following built-in [Azure Role-Based Access Control (RBAC)](https://docs.microsoft.com/azure/role-based-access-control/overview) role *is required for the current user* to enable creation of Azure Key Vault secrets, certificates and keys.
* *Key Vault Administartor* (https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)

For Azure role assignment instructions, refer to either the Azure [portal](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-portal), [CLI](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-cli) or [PowerShell](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-powershell) documents.

### Deployment Steps

1. Run `cd ~/e2e/1.security` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources
1. Use the [Azure portal to update your Key Vault secret values](https://docs.microsoft.com/azure/key-vault/secrets/quick-create-portal) (`GatewayConnection`, `AdminPassword`)

## 2 Network

### Deployment Steps

1. Run `cd ~/e2e/2.network` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 3 Storage

### Deployment Steps

1. Run `cd ~/e2e/3.storage` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 4 Storage Cache

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
curl -o $localDirectory/terraform-provider-avere_$latestVersion -L $downloadUrl
</code></p>
<p><code>
chmod 755 $localDirectory/terraform-provider-avere_$latestVersion
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
Invoke-WebRequest -OutFile $localDirectory\terraform-provider-avere_$latestVersion.exe -Uri $downloadUrl
</code></p>

### Deployment Steps

1. Run `cd ~/e2e/4.storage.cache` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. For [Avere vFXT](https://docs.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) deployment only,
   * Make sure the [Avere vFXT image terms have been accepted](https://docs.microsoft.com/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms) (only required once per Azure subscription)
   * Make sure you have at least 96 (32 x 3) cores quota available for [Esv3](https://docs.microsoft.com/azure/virtual-machines/ev3-esv3-series#esv3-series) machines in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 5 Compute Image

### Deployment Steps

1. Run `cd ~/e2e/5.compute.image` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment. Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources
1. After image template deployment, use the Azure portal or [Image Builder CLI](https://docs.microsoft.com/cli/azure/image/builder?#az-image-builder-run) to start image build runs

## 6 Compute Scheduler

### Deployment Steps

1. Run `cd ~/e2e/6.compute.scheduler` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **imageId** config references the correct custom image in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 7 Compute Farm

### Deployment Steps

1. Run `cd ~/e2e/7.compute.farm` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the **imageId** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystemMounts** config has the correct values (e.g., storage account name).
       * If your config includes cache mounting, which is the default config, make sure [4 Storage Cache](#4-storage-cache) is deployed and *running* before deploying this module.
   * Make sure the **fileSystemPermissions** config has the appropriate value for your environment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 8 Compute Workstation

### Deployment Steps

1. Run `cd ~/e2e/8.compute.workstation` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **imageId** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystemMounts** config has the correct values (e.g., storage cache mount).
       * If your config includes cache mounting, which is the default config, make sure [4 Storage Cache](#4-storage-cache) is deployed and *running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 9 GitOps

The following [GitHub Actions](https://github.com/features/actions) workflow files can optionally be leveraged to enable a Pull Request-driven automated deployment worklow. Both Terraform Plan and Terraform Apply command outputs are captured as Comments in each Pull Request.

* [Terraform Plan](.github/workflows/terraform.plan.yml) - Automatically triggered when a Pull Request is created with a commit in its own branch. May also be triggered manually via the GitHub Actions user interface.

* [Terraform Apply](.github/workflows/terraform.apply.yml) - Automatically triggerd when an open Pull Request is merged. May also be triggered manually via the GitHub Actions user interface.

To enable GitHub Actions to manage resource deployment within your Azure subscription, the following [GitHub Secrets (via Settings --> Secrets --> Actions)](https://docs.github.com/en/github-ae@latest/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) are required on your GitHub repository.

* ARM_TENANT_ID
* ARM_SUBSCRIPTION_ID
* ARM_CLIENT_ID
* ARM_CLIENT_SECRET

To generate new ARM_CLIENT_ID and ARM_CLIENT_SECRET values, the following Azure CLI command can be used.

<p><code>
&nbsp;&nbsp;&nbsp;$servicePrincipalName  = "Azure Artist Anywhere"
</code></p>
<p><code>
&nbsp;&nbsp;&nbsp;$servicePrincipalRole  = "Contributor"
</code></p>
<p><code>
&nbsp;&nbsp;&nbsp;$servicePrincipalScope = "/subscriptions/&lt;SUBSCRIPTION_ID&gt;"
</code></p>
<p><code>
&nbsp;&nbsp;&nbsp;az ad sp create-for-rbac --name $servicePrincipalName --role $servicePrincipalRole --scope $servicePrincipalScope
</code></p>

## 10 Render

Now that deployment of the AAA solution framework is complete, this section provides render job submission examples via the general-purpose **Deadline** [SubmitCommandLineJob](https://docs.thinkboxsoftware.com/products/deadline/10.1/1_User%20Manual/manual/command-line-arguments-jobs.html#submitcommandlinejob) API.

### 10.1 [Blender](https://www.blender.org)

For example, the following sample **Blender** output images were rendering in Azure via the **Deadline** job submission commands below.

#### Sprite Fright

<p align="center">
  <img src=".github/sprite-fright.png" alt="Sprite Fright" width="1024" />
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

#### White Lands

<p align="center">
  <img src=".github/white-lands.png" alt="White Lands" width="1024" />
</p>

#### Linux Render Farm
*The following job command can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name White-Lands -executable blender -arguments "-b -y -noaudio /mnt/show/read/blender/3.2/splash.blend --render-output /mnt/show/write/blender/3.2/splash####.png --render-frame 1"
</code></p>

#### Windows Render Farm
*The following job command can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name White-Lands -executable blender.exe -arguments "-b -y -noaudio R:\blender\3.2\splash.blend --render-output W:\blender\3.2\splash####.png --render-frame 1"
</code></p>

### 10.2 [Physically-Based Rendering Toolkit (PBRT)](https://pbrt.org)

For example, the following sample **PBRT** output image was rendering in Azure via the **Deadline** job submission command below.

#### Moana Island

<p align="center">
  <img src=".github/moana-island.png" alt="Moana Island" width="1024" />
</p>

> ######
> Unlike the Blender splash screen data that is included in the AAA GitHub repository within the Storage module, the following PBRT Moana Island data must be downloaded, decompressed and uploaded into your storage system *before* the following job command is submitted.
>
> * **Base Package** - https://azartist.blob.core.windows.net/bin/pbrt/moana/island-basepackage-v1.1.tgz
>
> * **PBRT Package** - https://azartist.blob.core.windows.net/bin/pbrt/moana/island-pbrt-v1.1.tgz

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
