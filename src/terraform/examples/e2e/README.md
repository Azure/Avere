# Azure Artist Anywhere (AAA) Solution Deployment Framework

Azure Artist Anywhere (AAA) is a *modular and customizable [infrastructure-as-code](https://learn.microsoft.com/devops/deliver/what-is-infrastructure-as-code) deployment framework* for the [Azure rendering solution architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). Enable your remote artists with global render farm scale using [Azure HPC Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc) and [Azure GPU Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu).

https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4

The following *core principles* are implemented throughout the Azure Artist Anywhere (AAA) solution deployment framework.
* Defense-in-depth layered security model across [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview), [Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) / [Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc.
* Any custom or 3rd-party software (such as a render manager, render engines, etc) in a [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) custom image is supported.
* Clean separation of AAA module deployment configuration files (**config.auto.tfvars**) and code template files (**main.tf**) via [Terraform](https://www.terraform.io).

| **Module Name** | **Module Description** | **Module Required for<br>Azure Burst Render?<br>(Compute Only)** | **Module Required for<br>All Azure Solution?<br>(Compute & Storage)** |
| - | - | - | - |
| [0 Global](#0-global) | Defines global config settings ([Azure region](https://azure.microsoft.com/regions)) and solution resources ([Terraform state storage](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm), [Monitor log storage](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview)). | Yes | Yes |
| [1 Network](#1-network) | Deploys [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview), [Private DNS](https://learn.microsoft.com/azure/dns/private-dns-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc with [VPN](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) gateway services. | Yes, if [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed.<br>Otherwise, No | Yes, if [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed.<br>Otherwise, No |
| [2 Storage](#2-storage) | Deploys native ([Blob NFS](https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support), [Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction), [NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)) and/or hosted ([Weka](https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform), [Hammerspace](https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5), [Qumulo](https://azuremarketplace.microsoft.com/marketplace/apps/qumulo1584033880660.qumulo-saas-mpp)) storage services with optional sample data load for [Blender](https://www.blender.org) and [PBRT](https://pbrt.org). | No | Yes |
| [3 Storage Cache](#3-storage-cache) | Deploys [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) cluster for highly-available and scalable storage file caching on-demand. | Yes | Maybe, depends on your scale requirements |
| [4 Image Builder](#4-image-builder) | Deploys [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) image definitions and templates for custom images built via the [Image Builder](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) service. | No, reference your custom render node *image.id* [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.render.farm/config.auto.tfvars#L14) | No, reference your custom render node *image.id* [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.render.farm/config.auto.tfvars#L14) |
| [5 Render Manager](#5-render-manager) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines) for render job scheduling via your custom render farm management server image. | No, use your current render manager | No, use your current render manager |
| [6 Render Farm](#6-render-farm) | Deploys [Virtual Machine Scale Sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) ([HPC Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc)) for scalable Linux and/or Windows render farm compute. | Yes | Yes |
| [7&#160;Artist&#160;Workstation](#7-artist-workstation) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/overview) ([GPU Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu)) for [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview)<br>and/or [Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | Yes |
| [8 GitOps](#8-gitops) | Enables [Terraform Plan](https://www.terraform.io/cli/commands/plan) and [Apply](https://www.terraform.io/cli/commands/apply) workflows via<br>[GitHub Actions](https://docs.github.com/actions) triggered by [Pull Requests](https://docs.github.com/pull-requests). | No | No |
| [9 Render](#9-render) | Sample render farm job submission from [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview)<br>and/or [Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | No |

For example, the following sample images were [rendered on Azure](https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4) via the Azure Artist Anywhere (AAA) solution deployment framework.

<p align="center">
  <img src=".github/images/blender-splash-3.4.png" width="1024" />
</p>

<p align="center">
  <img src=".github/images/moana-island.png" width="1024" />
</p>

## Installation Prerequisites

The following local installation prerequisites are required for the AAA solution deployment framework.<br>
As an alternative deployment management approach option, sample [GitOps](#8-gitops) enablement is also provided.
1. Make sure the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) is installed locally and accessible in your PATH environment variable.
1. Make sure the [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) is installed locally and accessible in your PATH environment variable.
1. Download the AAA end-to-end (e2e) solution source files via the following GitHub download link.
   * https://downgit.github.io/#/home?url=https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e
   * Unzip the downloaded `e2e.zip` file to your user home directory (`~/`).<br>Note that all local source file references below are relative to `~/e2e/`
1. Run `az account show` to ensure your current Azure subscription session context is set as expected. Verify the `id` property.<br>To change your current Azure subscription session context, run `az account set --subscription <subscriptionId>`

## 0 Global

### Deployment Steps

1. Run `cd ~/e2e/0.global` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `module/backend.config` for your deployment
1. Review and edit the config values in `module/variables.tf` for your deployment
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 1 Network

### Deployment Steps

1. Run `cd ~/e2e/1.network` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 2 Storage

### Deployment Steps

1. Run `cd ~/e2e/2.storage` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 3 Storage Cache

### Deployment Steps

1. Run `cd ~/e2e/3.storage.cache` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. For [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) deployment only (i.e., the following step does *not* apply to [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) deployment),
   * Make sure you have at least 96 cores (32 cores x 3 nodes) quota available for [Esv3](https://learn.microsoft.com/azure/virtual-machines/ev3-esv3-series#esv3-series) machines in your Azure subscription.
1. Download the latest [Terraform Avere provider](https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere) module via the following [Bash (Linux)](#terraform-avere-provider-linux) or [PowerShell (Windows)](#terraform-avere-provider-windows) commands.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

#### Terraform Avere Provider Linux

```latestVersion=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name)```

```downloadUrl=https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere```

```localDirectory=~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/${latestVersion:1}/linux_amd64```

```mkdir -p $localDirectory```

```curl -o $localDirectory/terraform-provider-avere_$latestVersion -L $downloadUrl```

```chmod 755 $localDirectory/terraform-provider-avere_$latestVersion```

#### Terraform Avere Provider Windows

```$latestVersion = (Invoke-WebRequest -Uri https://api.github.com/repos/Azure/Avere/releases/latest -UseBasicParsing | ConvertFrom-Json).tag_name```

```$downloadUrl = "https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere.exe"```

```$localDirectory = "$Env:AppData\terraform.d\plugins\registry.terraform.io\hashicorp\avere\$($latestVersion.Substring(1))\windows_amd64"```

```New-Item -ItemType Directory -Path $localDirectory -Force```

```(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $localDirectory -ChildPath "terraform-provider-avere_$latestVersion.exe"))```

## 4 Image Builder

### Deployment Steps

1. Run `cd ~/e2e/4.image.builder` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
    * Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming
1. After image template deployment, use the Azure portal or [Image Builder CLI](https://learn.microsoft.com/cli/azure/image/builder#az-image-builder-run) to start image build runs

## 5 Render Manager

### Deployment Steps

1. Run `cd ~/e2e/5.render.manager` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 6 Render Farm

### Deployment Steps

1. Run `cd ~/e2e/6.render.farm` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystemMounts*** configs have the correct values (e.g., storage account name).
       * If your config has cache mounts, make sure [3 Storage Cache](#3-storage-cache) is deployed and *running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 7 Artist Workstation

### Deployment Steps

1. Run `cd ~/e2e/7.artist.workstation` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystemMounts*** configs have the correct values (e.g., storage cache mount).
       * If your config has cache mounts, make sure [3 Storage Cache](#3-storage-cache) is deployed and *running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 8 GitOps

The following [GitHub Actions](https://github.com/features/actions) workflow files can optionally be leveraged to enable a Pull Request-driven automated deployment worklow. Both Terraform Plan and Terraform Apply command outputs are captured as Comments in each Pull Request.

* [Terraform Plan](.github/workflows/terraform.plan.yml) - Automatically triggered when a Pull Request is created with a commit in its own branch. May also be triggered manually via the GitHub Actions user interface.

* [Terraform Apply](.github/workflows/terraform.apply.yml) - Automatically triggerd when an open Pull Request is merged. May also be triggered manually via the GitHub Actions user interface.

To enable GitHub Actions to manage resource deployment within your Azure subscription, the following [GitHub Secrets (via Settings --> Secrets --> Actions)](https://docs.github.com/en/github-ae@latest/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) are required on your GitHub repository.

* ARM_TENANT_ID
* ARM_SUBSCRIPTION_ID
* ARM_CLIENT_ID
* ARM_CLIENT_SECRET

To generate new ARM_CLIENT_ID and ARM_CLIENT_SECRET values, the following Azure CLI command can be used.

```$servicePrincipalName = "Azure Artist Anywhere"```

```$servicePrincipalRole = "Contributor"```

```$servicePrincipalScope = "/subscriptions/&lt;SUBSCRIPTION_ID&gt;"```

```az ad sp create-for-rbac --name $servicePrincipalName --role $servicePrincipalRole --scope $servicePrincipalScope```

## 9 Render

Now that deployment of the AAA solution framework is complete, this final section provides render job submission examples for multiple render engines (Blender, Physically-Based Ray Tracer) via multiple render managers (Royal Render, Deadline, Qube).

### 9.1 [Blender](https://www.blender.org) [Splash Screen (3.4)](https://www.blender.org/download/demo-files/#splash)

<p align="center">
  <img src=".github/images/blender-splash-3.4.png" width="1024" />
</p>

#### 9.1.1 [Royal Render](https://www.royalrender.de) (*Linux*)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```rrSubmitterconsole --name blender-splash blender --background /mnt/data/read/blender/3.4/splash.blend --render-output /mnt/data/write/blender/3.4/splash --enable-autoexec --render-frame 1```

#### 9.1.2 [Qube](https://www.pipelinefx.com) (*Linux*)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```qbsub --name blender-splash blender --background /mnt/data/read/blender/3.4/splash.blend --render-output /mnt/data/write/blender/3.4/splash --enable-autoexec --render-frame 1```

#### 9.1.3 [Deadline](https://www.awsthinkbox.com/deadline) (*Linux*)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender -arguments "--background /mnt/data/read/blender/3.4/splash.blend --render-output /mnt/data/write/blender/3.4/splash --enable-autoexec --render-frame 1"```

#### 9.1.4 [Royal Render](https://www.royalrender.de) (*Windows*)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```rrSubmitterconsole --name blender-splash blender --background R:\blender\3.4\splash.blend --render-output W:\blender\3.4\splash --enable-autoexec --render-frame 1```

#### 9.1.5 [Qube](https://www.pipelinefx.com) (*Windows*)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```qbsub --name blender-splash blender --background R:\blender\3.4\splash.blend --render-output W:\blender\3.4\splash --enable-autoexec --render-frame 1```

#### 9.1.6 [Deadline](https://www.awsthinkbox.com/deadline) (*Windows*)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender -arguments "--background R:\blender\3.4\splash.blend --render-output W:\blender\3.4\splash --enable-autoexec --render-frame 1"```

### 9.2 [Physically-Based Ray Tracer (PBRT)](https://pbrt.org) [Moana Island](https://www.disneyanimation.com/resources/moana-island-scene/)

<p align="center">
  <img src=".github/images/moana-island.png" width="1024" />
</p>

#### 9.2.1 [Royal Render](https://www.royalrender.de) (*Linux*)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```rrSubmitterconsole --name moana-island-v3 pbrt3 --outfile /mnt/data/write/pbrt/moana/island-v3.png /mnt/data/read/pbrt/moana/island/pbrt/island.pbrt```

```rrSubmitterconsole --name moana-island-v4 pbrt4 --outfile /mnt/data/write/pbrt/moana/island-v4.png /mnt/data/read/pbrt/moana/island/pbrt-v4/island.pbrt```

#### 9.2.2 [Qube](https://www.pipelinefx.com) (*Linux*)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```qbsub --name moana-island-v3 pbrt3 --outfile /mnt/data/write/pbrt/moana/island-v3.png /mnt/data/read/pbrt/moana/island/pbrt/island.pbrt```

```qbsub --name moana-island-v4 pbrt4 --outfile /mnt/data/write/pbrt/moana/island-v4.png /mnt/data/read/pbrt/moana/island/pbrt-v4/island.pbrt```

#### 9.2.3 [Deadline](https://www.awsthinkbox.com/deadline) (*Linux*)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name moana-island-v3 -executable pbrt3 -arguments "--outfile /mnt/data/write/pbrt/moana/island-v3.png /mnt/data/read/pbrt/moana/island/pbrt/island.pbrt"```

```deadlinecommand -SubmitCommandLineJob -name moana-island-v4 -executable pbrt4 -arguments "--outfile /mnt/data/write/pbrt/moana/island-v4.png /mnt/data/read/pbrt/moana/island/pbrt-v4/island.pbrt"```

#### 9.2.4 [Royal Render](https://www.royalrender.de) (*Windows*)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```rrSubmitterconsole --name moana-island-v3 pbrt3 --outfile W:\pbrt\moana\island-v3.png R:\pbrt\moana\island\pbrt\island.pbrt```

```rrSubmitterconsole --name moana-island-v4 pbrt4 --outfile W:\pbrt\moana\island-v4.png R:\pbrt\moana\island\pbrt-v4\island.pbrt```

#### 9.2.5 [Qube](https://www.pipelinefx.com) (*Windows*)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```qbsub --name moana-island-v3 pbrt3 --outfile W:\pbrt\moana\island-v3.png R:\pbrt\moana\island\pbrt\island.pbrt```

```qbsub --name moana-island-v4 pbrt4 --outfile W:\pbrt\moana\island-v4.png R:\pbrt\moana\island\pbrt-v4\island.pbrt```

#### 9.2.6 [Deadline](https://www.awsthinkbox.com/deadline) (*Windows*)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name moana-island-v3 -executable pbrt3 -arguments "--outfile W:\pbrt\moana\island-v3.png R:\pbrt\moana\island\pbrt\island.pbrt"```

```deadlinecommand -SubmitCommandLineJob -name moana-island-v4 -executable pbrt4 -arguments "--outfile W:\pbrt\moana\island-v4.png R:\pbrt\moana\island\pbrt-v4\island.pbrt"```

## 10 Appendix

The following splash screens from previous Blender versions were rendered in Azure using the AAA solution deployment framework.

### 10.1 Blender 3.0 Splash Screen

<p align="center">
  <img src=".github/images/blender-splash-3.0.png" width="1024" />
</p>

### 10.2 Blender 3.1 Splash Screen

<p align="center">
  <img src=".github/images/blender-splash-3.1.jpg" width="1024" />
</p>

### 10.3 Blender 3.2 Splash Screen

<p align="center">
  <img src=".github/images/blender-splash-3.2.png" width="1024" />
</p>

### 10.4 Blender 3.3 Splash Screen

<p align="center">
  <img src=".github/images/blender-splash-3.3.png" width="1024" />
</p>

If you have any questions or issues, please contact rick.shahid@microsoft.com
