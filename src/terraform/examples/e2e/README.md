# Azure Artist Anywhere (AAA) Solution Deployment Framework

Azure Artist Anywhere (AAA) is a *modular & configurable [infrastructure-as-code](https://learn.microsoft.com/devops/deliver/what-is-infrastructure-as-code) solution deployment framework* for Azure HPC & AI [Rendering](https://azure.microsoft.com/solutions/high-performance-computing/rendering). Enable remote artist creativity with Azure [global scale](https://azure.microsoft.com/global-infrastructure) and distributed computing innovation via [HPC-Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-hpc) and [GPU-Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu) infrastructure.

The following design principles are implemented across each module of the Azure Artist Anywhere (AAA) solution deployment framework.
* Defense-in-depth layered security model across [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview), [Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) / [Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc
* Any custom or 3rd-party software (such as a render manager, render engines, etc) in a [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) custom image is supported
* Clean separation of AAA module deployment configuration files (***config.auto.tfvars***) and resource template files (****.tf***) via [Terraform](https://www.terraform.io)

| **Module Name** | **Module Description** | **Is Module Required<br>for Burst Render?<br>(*Compute Only*)** | **Is Module Required<br>for Full Solution?<br>(*Compute & Storage*)** |
| - | - | - | - |
| [0&#160;Global&#160;Foundation](#0-global-foundation) | Defines&#160;global&#160;config&#160;([Azure&#160;region(s)](https://azure.microsoft.com/regions))&#160;and&#160;core&#160;solution resources ([Terraform state storage](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm), [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview), etc). | Yes | Yes |
| [1 Virtual Network](#1-virtual-network) | Deploys [Virtual Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview), [Private DNS](https://learn.microsoft.com/azure/dns/private-dns-overview), [Network Security Groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview), etc with [VPN](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://learn.microsoft.com/azure/expressroute/expressroute-about-virtual-network-gateways) gateway services. | Yes,&#160;if&#160;[Virtual&#160;Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed | Yes,&#160;if&#160;[Virtual&#160;Network](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview) not yet deployed |
| [2 Image Builder](#2-image-builder) | Deploys [Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) image definitions and templates<br />for building custom images via the [Image Builder](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview) service. | No, use your custom images via [image.id](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L14) | No, use your custom images via [image.id](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L14) |
| [3 File Storage](#3-file-storage) | Deploys native ([Blob [NFS]](https://learn.microsoft.com/azure/storage/blobs/network-file-system-protocol-support), [Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction) or [NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)) or hosted ([Weka](https://azuremarketplace.microsoft.com/marketplace/apps/weka1652213882079.weka_data_platform) or [Hammerspace](https://azuremarketplace.microsoft.com/marketplace/apps/hammerspace.hammerspace_4_6_5)) storage with optional sample scene data loaded for [PBRT](https://pbrt.org), [Blender](https://www.blender.org) and/or [MoonRay](https://openmoonray.org) rendering. | No | Yes |
| [4 File Cache](#4-file-cache) | Deploys [HPC Cache](https://learn.microsoft.com/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://learn.microsoft.com/azure/avere-vfxt/avere-vfxt-overview) storage cluster for highly-available and scalable on-premises file caching on-demand. | Yes | No |
| [5 Render Manager](#5-render-manager) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines) for render job management<br/>via any 3rd-party rendering job scheduling software. | No | No |
| [6 Render Farm](#6-render-farm) | Deploys  [Virtual Machine Scale Sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) or [Batch](https://learn.microsoft.com/azure/batch/batch-technical-overview) for highly-scalable Linux and/or Windows render farm compute.<br/>Deploys [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/overview) ([DALL-E 2](https://openai.com/dall-e-2)) with [Semantic Kernel](https://learn.microsoft.com/semantic-kernel/overview/). | Yes, Azure OpenAI is *optional* config [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L515) | Yes, Azure OpenAI is *optional* config [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/6.Render.Farm/config.auto.tfvars#L515) |
| [7&#160;Artist&#160;Workstation](#7-artist-workstation) | Deploys [Virtual Machines](https://learn.microsoft.com/azure/virtual-machines/overview) ([GPU Enabled](https://learn.microsoft.com/azure/virtual-machines/sizes-gpu)) for [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview) and/or<br>[Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations with [HP Anyware](https://www.teradici.com). | No | No |
| [8 Render Jobs](#8-render-jobs) | Example render farm job submissions from [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/overview) and/or<br>[Windows](https://learn.microsoft.com/azure/virtual-machines/windows/overview) remote artist workstations with [HP Anyware](https://www.teradici.com). | No | No |

For example, the following sample images were [rendered on Azure](https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4) via the Azure Artist Anywhere (AAA) solution deployment framework.

<p align="center">
  <img src=".github/images/moana-island.png" />
</p>

<p align="center">
  <img src=".github/images/blender-splash-3.4.png" />
</p>

## Installation Prerequisites

The following local installation prerequisites are required for the AAA solution deployment framework.<br>
1. Make sure the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) is installed locally and accessible in your PATH environment variable.
1. Make sure the [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) is installed locally and accessible in your PATH environment variable.
1. Run `az account show` to ensure your current Azure subscription session context is set as expected. Verify the `id` property.<br>To change your current Azure subscription session context, run `az account set --subscription <subscriptionId>`
1. Download this GitHub repository to your local workstation, which enables easy module configuration and deployment.

## 0 Global Foundation

### Module Configuration & Deployment

1. Review and edit the config values in `module/backend.config` for your deployment
1. Review and edit the config values in `module/variables.tf` for your deployment
   * If Key Vault is enabled [here](https://github.com/Azure/Avere/blob/main/src/terraform/examples/e2e/0.Global.Foundation/module/variables.tf#L35), make sure the [Key Vault Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator) role is assigned to the current user via [Role-Based Access Control (RBAC)](https://learn.microsoft.com/azure/role-based-access-control/overview).
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 1 Virtual Network

### Module Configuration & Deployment

1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 2 Image Builder

### Module Configuration & Deployment

1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming
1. After image template deployment, use the Azure portal or [Image Builder CLI](https://learn.microsoft.com/cli/azure/image/builder#az-image-builder-run) to start image build runs

## 3 File Storage

### Module Configuration & Deployment

1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 4 File Cache

### Module Configuration & Deployment

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

### Module Configuration & Deployment

1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 6 Render Farm

### Module Configuration & Deployment

1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystems** config has the correct values for your target storage environment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 7 Artist Workstation

### Module Configuration & Deployment

1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the **image.id** config references the correct custom image in your Azure subscription.
   * Make sure the **fileSystems** config has the correct values for your target storage environment.
1. Run `terraform init -backend-config ../0.Global.Foundation/module/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review the displayed Terraform deployment plan to add, change and/or destroy Azure resources *before* confirming

## 8 Render Jobs

Now that deployment of the AAA solution framework is complete, this final section provides render job submission examples for multiple render engines (Physically-Based Ray Tracer, Blender).

### 8.1 [Physically-Based Ray Tracer (PBRT)](https://pbrt.org) [Moana Island](https://www.disneyanimation.com/resources/moana-island-scene/)

<p align="center">
  <img src=".github/images/moana-island.png" />
</p>

#### 8.1.1 Azure *Linux* Render Farm with [AWS Thinkbox Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name moana-island -executable pbrt -arguments "--outfile /mnt/content/pbrt/moana/island-v4.png /mnt/content/pbrt/moana/island/pbrt-v4/island.pbrt"```

#### 8.1.2 Azure *Windows* Render Farm with [AWS Thinkbox Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name moana-island -executable pbrt.exe -arguments "--outfile H:\pbrt\moana\island-v4.png H:\pbrt\moana\island\pbrt-v4\island.pbrt"```

### 8.2 [Blender](https://www.blender.org) [Splash Screen (3.4)](https://www.blender.org/download/demo-files/#splash)

<p align="center">
  <img src=".github/images/blender-splash-3.4.png" />
</p>

#### 8.2.1 Azure *Linux* Render Farm with [AWS Thinkbox Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender -arguments "--background /mnt/content/blender/3.4/splash.blend --render-output /mnt/content/blender/3.4/splash --enable-autoexec --render-frame 1"```

#### 8.2.2 Azure *Windows* Render Farm with [AWS Thinkbox Deadline](https://www.awsthinkbox.com/deadline)

*The following render farm job submission command can be submitted from a **Linux** and/or **Windows** artist workstation.*

```deadlinecommand -SubmitCommandLineJob -name blender-splash -executable blender.exe -arguments "--background H:\blender\3.4\splash.blend --render-output H:\blender\3.4\splash --enable-autoexec --render-frame 1"```

https://user-images.githubusercontent.com/22285652/202864874-e48070dc-deaa-45ee-a8ed-60ff401955f0.mp4

If you have any questions or issues, please contact rick.shahid@microsoft.com
