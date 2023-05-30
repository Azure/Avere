# Azure Artist Anywhere (AAA) Solution Deployment Framework

Azure Artist Anywhere (AAA) is a *modular and customizable [infrastructure-as-code](https://learn.microsoft.com/devops/deliver/what-is-infrastructure-as-code) deployment framework* for Azure [rendering](https://azure.microsoft.com/solutions/high-performance-computing/rendering) and [gaming](https://azure.microsoft.com/solutions/gaming) solution architectures. Enable your remote artists with [global scale](https://azure.microsoft.com/global-infrastructure) using [Azure HPC Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc) and [Azure GPU Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu).

https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4

The following *core principles* are implemented throughout the Azure Artist Anywhere (AAA) solution deployment framework.
* Defense-in-depth layered security model across [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview), [Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) / [Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc.
* Any custom or 3rd-party software (such as a render manager, render engines, etc) in a [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) custom image is supported.
* Clean separation of AAA module deployment configuration files (**config.auto.tfvars**) and code template files (**main.tf**) via [Terraform](https://www.terraform.io).

| **Module Name** | **Module Description** | **Module Required for<br>Azure Burst Render?<br>(Compute Only)** | **Module Required for<br>All Azure Solution?<br>(Compute & Storage)** |
| - | - | - | - |
| [0&#160;Global&#160;Foundation](#0-global-foundation) | Defines global config ([Azure region](https://azure.microsoft.com/regions)) and core solution resources ([Terraform state storage](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm), [Monitor log storage](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview)). | Yes | Yes |
| [1 Virtual Network](#1-virtual-network) | Deploys [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview), [Private DNS](https://learn.microsoft.com/azure/dns/private-dns-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc with [VPN](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) gateway services. | Yes, if [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed.<br>Otherwise, No | Yes, if [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed.<br>Otherwise, No |
| [2 Image Builder](#2-image-builder) | Deploys [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) image definitions and templates for custom images built via the [Image Builder](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) service. | No | No |
| [3 Storage](#3-storage) | Deploys native ([Blob NFS](https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support), [Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction), [NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)) and/or hosted ([Weka](https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform), [Hammerspace](https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5), [Qumulo](https://azuremarketplace.microsoft.com/marketplace/apps/qumulo1584033880660.qumulo-saas-mpp)) storage services with optional sample data load for [Blender](https://www.blender.org) and [PBRT](https://pbrt.org). | No | Yes |
| [4 Storage Cache](#4-storage-cache) | Deploys [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) cluster for highly-available and scalable storage file caching on-demand. | Yes | Maybe, depends on your scale requirements |
| [5 Render Manager](#5-render-manager) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines) for render job scheduling via your custom render farm management server image. | No, use your current render manager | No, use your current render manager |
| [6 Render Farm](#6-render-farm) | Deploys [Virtual Machine Scale Sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) ([HPC Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc)) for scalable Linux and/or Windows render farm compute. | Yes | Yes |
| [7 Render AI](#7-render-ai) | Deploys [Open AI](https://learn.microsoft.com/azure/cognitive-services/openai/overview) services, including [DALL-E 2](https://openai.com/product/dall-e-2) for text-to-image generation. | No | No |
| [8&#160;Artist&#160;Workstation](#8-artist-workstation) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/overview) ([GPU Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu)) for [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview)<br>and/or [Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | No |
| [9 GitOps](#9-gitops) | Enables [Terraform Plan](https://www.terraform.io/cli/commands/plan) and [Apply](https://www.terraform.io/cli/commands/apply) workflows via<br>[GitHub Actions](https://docs.github.com/actions) triggered by [Pull Requests](https://docs.github.com/pull-requests). | No | No |
| [10 Render](#10-render) | Sample render farm job submission from [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview)<br>and/or [Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations. | No | No |

For example, the following sample images were [rendered on Azure](https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4) via the Azure Artist Anywhere (AAA) solution deployment framework.

<p align="center">
  <img src=".github/images/blender-splash-3.5.png" />
</p>

<p align="center">
  <img src=".github/images/blender-splash-3.4.png" />
</p>

<p align="center">
  <img src=".github/images/blender-splash-3.3.png" />
</p>

<p align="center">
  <img src=".github/images/moana-island.png" />
</p>

## Installation Prerequisites

The following local installation prerequisites are required for the AAA solution deployment framework.<br>
As an alternative deployment management approach option, sample [GitOps](#9-gitops) enablement is also provided.
1. Make sure the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) is installed locally and accessible in your PATH environment variable.
1. Make sure the [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) is installed locally and accessible in your PATH environment variable.
1. Download the AAA end-to-end (e2e) solution source files via the following GitHub download link.
   * https://downgit.github.io/#/home?url=https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e
   * Unzip the downloaded `e2e.zip` file to your user home directory (`~/`).<br>Note that all local source file references below are relative to `~/e2e/`
1. Run `az account show` to ensure your current Azure subscription session context is set as expected. Verify the `id` property.<br>To change your current Azure subscription session context, run `az account set --subscription <subscriptionId>`

## 0 Global Foundation

### Deployment Steps

1. Run `cd ~/e2e/0.Global.Foundation` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `module/backend.config` for your deployment
1. Review and edit the config values in `module/variables.tf` for your deployment
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 1 Virtual Network

### Deployment Steps

1. Run `cd ~/e2e/1.Virtual.Network` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 2 Image Builder

### Deployment Steps

1. Run `cd ~/e2e/2.Image.Builder` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
    * Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming
1. After image template deployment, use the Azure portal or [Image Builder CLI](https://learn.microsoft.com/cli/azure/image/builder#az-image-builder-run) to start image build runs

## 3 Storage

### Deployment Steps

1. Run `cd ~/e2e/3.Storage` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 4 Storage Cache

### Deployment Steps

1. Run `cd ~/e2e/4.Storage.Cache` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. For [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) deployment only (i.e., the following step does *not* apply to [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) deployment),
   * Make sure you have at least 96 cores (32 cores x 3 nodes) quota available for [Esv3](https://learn.microsoft.com/azure/virtual-machines/ev3-esv3-series#esv3-series) machines in your Azure subscription.
1. Download the latest [Terraform Avere provider](https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere) module via the following [Bash (Linux)](#terraform-avere-provider-linux) or [PowerShell (Windows)](#terraform-avere-provider-windows) commands.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
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

## 5 Render Manager

### Deployment Steps

1. Run `cd ~/e2e/5.Render.Manager` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 6 Render Farm

### Deployment Steps

1. Run `cd ~/e2e/6.Render.Farm` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
   * Make sure the **storageCache** read and write boolean switches are set properly for your environment.
   * Make sure the **fileSystemMount** config has the correct values for your environment (e.g., storage account name).
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 7 Render AI

### Deployment Steps

1. Run `cd ~/e2e/7.Render.AI` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 8 Artist Workstation

### Deployment Steps

1. Run `cd ~/e2e/8.Artist.Workstation` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
   * Make sure the **storageCache** read and write boolean switches are set properly for your environment.
   * Make sure the **fileSystemMount** config has the correct values for your environment (e.g., storage cache mount).
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

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

```$servicePrincipalName = "Azure Artist Anywhere"```

```$servicePrincipalRole = "Contributor"```

```$servicePrincipalScope = "/subscriptions/&lt;SUBSCRIPTION_ID&gt;"```

```az ad sp create-for-rbac --name $servicePrincipalName --role $servicePrincipalRole --scope $servicePrincipalScope```

## 10 Render

Now that deployment of the AAA solution framework is complete, this final section provides render job submission examples for multiple render engines (Blender, Physically-Based Ray Tracer).

### 10.1 [Blender](https://www.blender.org) [Splash Screen (3.5)](https://www.blender.org/download/demo-files/#splash)

<p align="center">
  <img src=".github/images/blender-splash-3.5.png" />
</p>

#### 10.1.1 Azure *Linux* Render Farm with [Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender -arguments "--background /mnt/data/read/blender/3.5/splash.blend --render-output /mnt/data/write/blender/3.5/splash --enable-autoexec --render-frame 1"```

#### 10.1.2 Azure *Windows* Render Farm with [Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender -arguments "--background R:\blender\3.5\splash.blend --render-output W:\blender\3.5\splash --enable-autoexec --render-frame 1"```

### 10.2 [Physically-Based Ray Tracer (PBRT)](https://pbrt.org) [Moana Island](https://www.disneyanimation.com/resources/moana-island-scene/)

<p align="center">
  <img src=".github/images/moana-island.png" />
</p>

#### 10.2.1 Azure *Linux* Render Farm with [Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name moana-island-v3 -executable pbrt3 -arguments "--outfile /mnt/data/write/pbrt/moana/island-v3.png /mnt/data/read/pbrt/moana/island/pbrt/island.pbrt"```

```deadlinecommand -SubmitCommandLineJob -name moana-island-v4 -executable pbrt4 -arguments "--outfile /mnt/data/write/pbrt/moana/island-v4.png /mnt/data/read/pbrt/moana/island/pbrt-v4/island.pbrt"```

#### 10.2.2 Azure *Linux* Render Farm with [Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission commands can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name moana-island-v3 -executable pbrt3 -arguments "--outfile W:\pbrt\moana\island-v3.png R:\pbrt\moana\island\pbrt\island.pbrt"```

```deadlinecommand -SubmitCommandLineJob -name moana-island-v4 -executable pbrt4 -arguments "--outfile W:\pbrt\moana\island-v4.png R:\pbrt\moana\island\pbrt-v4\island.pbrt"```

If you have any questions or issues, please contact rick.shahid@microsoft.com
