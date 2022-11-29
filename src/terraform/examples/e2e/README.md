# Azure Artist Anywhere (AAA) Solution Deployment Framework

Azure Artist Anywhere (AAA) is a *modular and customizable [infrastructure-as-code](https://learn.microsoft.com/devops/deliver/what-is-infrastructure-as-code) deployment framework* for the [Azure rendering solution architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). Enable your remote artists with global render farm scale using [Azure HPC Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc) and [Azure GPU Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu).

https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4

The following *core design principles* are implemented throughout the AAA solution deployment framework.
* Integration of security best practices, including [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview), [Private Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview) and [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview).
* Any custom or 3rd-party software (render manager, render engines, etc) in a [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) custom image is supported.
* Clean separation of AAA module deployment configuration files (*config.auto.tfvars*) and code files (*main.tf*) via Terraform.

| **Module Name** | **Module Description** | **Required for<br>Compute Burst?** | **Required for<br>All Cloud?** |
| --------------- | ---------------------- | ---------------------------------- | ------------------------------ |
| [0 Global](#0-global) | Defines global variables (e.g., Azure region) and Terraform backend state storage config. | Yes | Yes |
| [1 Security](#1-security) | Deploys [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview) and [Blob Storage](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction) for Terraform state file management. | Yes | Yes |
| [2 Network](#2-network) | Deploys [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) and [Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview) with [VPN](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) hybrid networking services. | Yes, if [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not deployed. Otherwise, No | Yes, if [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not deployed. Otherwise, No |
| [3 Storage](#3-storage) | Deploys [Blob (NFS v3 with sample content)](https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support), [Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction), [NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) or [Hammerspace](https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5) storage. | No | Yes |
| [4 Storage Cache](#4-storage-cache) | Deploys [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) for highly-available and scalable file caching. | Yes | Maybe, depends on your<br>render scale requirements |
| [5 Compute Image](#5-compute-image) | Deploys [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) images that are built via the managed [Image Builder](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) service. | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/7.compute.farm/config.auto.tfvars#L10) | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/7.compute.farm/config.auto.tfvars#L10) |
| [6 Compute Scheduler](#6-compute-scheduler) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines) for job scheduling with optional [CycleCloud](https://learn.microsoft.com/azure/cyclecloud/overview) integration. | No, continue to use your current job scheduler | No, specify your custom *imageId* reference [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.compute.scheduler/config.auto.tfvars#L10) |
| [7 Compute Farm](#7-compute-farm) | Deploys [Virtual Machine Scale Sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) for [Linux](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) and/or [Windows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) render farms. | Yes, if [CycleCloud](https://learn.microsoft.com/azure/cyclecloud/overview) not deployed. Otherwise, No | Yes, if [CycleCloud](https://learn.microsoft.com/azure/cyclecloud/overview) not deployed. Otherwise, No |
| [8&#160;Compute&#160;Workstation](#8-compute-workstation) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines) for [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview) and/or [Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | Yes |
| [9 GitOps](#9-gitops) | Enables [Terraform Plan](https://www.terraform.io/cli/commands/plan) and [Apply](https://www.terraform.io/cli/commands/apply) workflows via [GitHub Actions](https://docs.github.com/actions) triggered by [Pull Requests](https://docs.github.com/pull-requests). | No | No |
| [10 Render](#10-render) | Submits render farm jobs from [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview) and/or [Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | No |

For example, the following sample output images were rendering in Azure via the AAA solution deployment framework.

[Sprite Fright](#sprite-fright)
<p align="center">
  <img src=".github/images/sprite-fright.png" alt="Sprite Fright" width="1024" />
</p>

[White Lands](#white-lands)
<p align="center">
  <img src=".github/images/white-lands.png" alt="White Lands" width="1024" />
</p>

[Moana Island](#moana-island)
<p align="center">
  <img src=".github/images/moana-island.png" alt="Moana Island" width="1024" />
</p>

## Deployment Prerequisites

To manage deployment of the AAA solution from your local workstation, the following prerequisite setup steps are required. As an alternative deployment management approach, [GitOps](#9-gitops) enablement is also provided.
1. Make sure the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) is installed locally and accessible in your path environment variable.
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

*Before deploying the Security module*, the following built-in [Azure Role-Based Access Control (RBAC)](https://learn.microsoft.com/azure/role-based-access-control/overview) role *is required for the current user* to enable creation of Azure Key Vault secrets, certificates and keys.
* *Key Vault Administartor* (https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)

For Azure role assignment instructions, refer to either the Azure [portal](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal), [CLI](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli) or [PowerShell](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-powershell) documents.

### Deployment Steps

1. Run `cd ~/e2e/1.security` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources
1. Use the [Azure portal to update your Key Vault secret values](https://learn.microsoft.com/azure/key-vault/secrets/quick-create-portal) (`GatewayConnection`, `AdminPassword`)

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
   * If Hammerspace is configured for deployment, the [Hammerspace Azure marketplace image terms](https://mpcprodsa.blob.core.windows.net/marketplaceterms/3EDEF_marketplaceterms_VIRTUALMACHINE%253a24AAK2OAIZEAWW5H4MSP5KSTVB6NDKKRTUBAU23BRFTWN4YC2MQLJUB5ZEYUOUJBVF3YK34CIVPZL2HWYASPGDUY5O2FWEGRBYOXWZE5Y.txt) are automatically accepted.
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
$latestVersion = (Invoke-WebRequest -Uri https://api.github.com/repos/Azure/Avere/releases/latest -UseBasicParsing | ConvertFrom-Json).tag_name
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
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $localDirectory -ChildPath "terraform-provider-avere_$latestVersion.exe"))
</code></p>

### Deployment Steps

1. Run `cd ~/e2e/4.storage.cache` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. For [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) deployment only,
   * If Avere vFXT is configured for deployment, the [Avere vFXT Azure marketplace image terms](https://mpcprodsa.blob.core.windows.net/marketplaceterms/3EDEF_marketplaceterms_VIRTUALMACHINE%253a24AAK2OAIZEAWW5H4MSP5KSTVB6NDKKRTUBAU23BRFTWN4YC2MQLJUB5ZEYUOUJBVF3YK34CIVPZL2HWYASPGDUY5O2FWEGRBYOXWZE5Y.txt) are automatically accepted.
   * Make sure you have at least 96 cores (32 cores x 3 nodes) quota available for [Esv3](https://learn.microsoft.com/azure/virtual-machines/ev3-esv3-series#esv3-series) machines in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources

## 5 Compute Image

### Deployment Steps

1. Run `cd ~/e2e/5.compute.image` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * By the default config, the [Alma Linux Azure marketplace image terms](https://mpcprodsa.blob.core.windows.net/marketplaceterms/3EDEF_marketplaceterms_VIRTUALMACHINE%253a24AAK2OAIZEAWW5H4MSP5KSTVB6NDKKRTUBAU23BRFTWN4YC2MQLJUB5ZEYUOUJBVF3YK34CIVPZL2HWYASPGDUY5O2FWEGRBYOXWZE5Y.txt) are automatically accepted for the Linux distribution image.
    * Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan to add, change and/or destroy Azure resources
1. After image template deployment, use the Azure portal or [Image Builder CLI](https://learn.microsoft.com/cli/azure/image/builder#az-image-builder-run) to start image build runs

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
   * Make sure the **fileSystemMounts*** configs have the correct values (e.g., storage account name).
       * If your config has cache mounts, make sure [4 Storage Cache](#4-storage-cache) is deployed and *running* before deploying this module.
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
   * Make sure the **fileSystemMounts*** configs have the correct values (e.g., storage cache mount).
       * If your config has cache mounts, make sure [4 Storage Cache](#4-storage-cache) is deployed and *running* before deploying this module.
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
  <img src=".github/images/sprite-fright.png" alt="Sprite Fright" width="1024" />
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
  <img src=".github/images/white-lands.png" alt="White Lands" width="1024" />
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

### 10.2 [Physically-Based Ray Tracer (PBRT)](https://pbrt.org)

For example, the following sample **PBRT** output image was rendering in Azure via the **Deadline** job submission command below.

#### Moana Island

<p align="center">
  <img src=".github/images/moana-island.png" alt="Moana Island" width="1024" />
</p>

######
Unlike the Blender splash screen data that is included in the AAA GitHub repository within the Storage module, the following PBRT Moana Island data must be downloaded, decompressed and uploaded into your storage system *before* the following job command is submitted.

* **[Moana Island Base Data (44.8 GiB Compressed)](https://azrender.blob.core.windows.net/bin/PBRT/moana/island-basepackage-v1.1.tgz?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D)**

* **[Moana Island PBRT v3 Data (6.3 GiB Compressed)](https://azrender.blob.core.windows.net/bin/PBRT/moana/island-pbrt-v1.1.tgz?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D)**

* **[Moana Island PBRT v4 Data (5.5 GiB Compressed)](https://azrender.blob.core.windows.net/bin/PBRT/moana/island-pbrtV4-v2.0.tgz?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D)**

#### Linux Render Farm
*The following job commands can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name Moana-Island-v3 -executable pbrt3 -arguments "--outfile /mnt/show/write/pbrt/moana/island-v3.png /mnt/show/read/pbrt/moana/island/pbrt/island.pbrt"
</code></p>

<p><code>
deadlinecommand -SubmitCommandLineJob -name Moana-Island-v4 -executable pbrt4 -arguments "--outfile /mnt/show/write/pbrt/moana/island-v4.png /mnt/show/read/pbrt/moana/island/pbrt-v4/island.pbrt"
</code></p>

#### Windows Render Farm
*The following job commands can be submitted from a **Linux** or **Windows** artist workstation.*

<p><code>
deadlinecommand -SubmitCommandLineJob -name Moana-Island-v3 -executable pbrt3 -arguments "--outfile W:\pbrt\moana\island-v3.png R:\pbrt\moana\island\pbrt\island.pbrt"
</code></p>

<p><code>
deadlinecommand -SubmitCommandLineJob -name Moana-Island-v4 -executable pbrt4 -arguments "--outfile W:\pbrt\moana\island-v4.png R:\pbrt\moana\island\pbrt-v4\island.pbrt"
</code></p>

If you have any questions or issues, please contact rick.shahid@microsoft.com
