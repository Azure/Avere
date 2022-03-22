# Azure Artist Anywhere (AAA) Solution Deployment Framework

This folder contains the end-to-end modular framework for automated deployment of the [Azure Artist Anywhere (AAA) rendering architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). By extending your rendering pipeline with [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview), you can enable remote artists across [Azure Regions](https://azure.microsoft.com/en-us/global-infrastructure/geographies) and scale your Azure render farm. You can choose to connect your on-premises asset storage via [Azure Hybrid Networking](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking) and/or deploy Azure (multi-regional) storage.

The following core principles are implemented throughout this Azure rendering solution framework.
* Incorporation of security best practices ([Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview), [Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview), etc.) 
* Separation of module deployment configuration (**config.auto.tfvars**) and code (**main.tf**) files.
* Any software (render manager, renderers, etc.) in a [Compute Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries) custom image is supported.

| Module | Required? | Description |
| ------ | --------- | ----------- |
| [0 Global](#0-global) | Yes | Defines global variables and Terraform backend configuration for the solution. |
| [1 Security](#1-security) | Yes | Deploys [Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview) and [Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) for Terraform state files. |
| [2 Network](#2-network) | Yes, if [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) not<br/>deployed. Otherwise, No | Deploys [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) with [VPN](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways) hybrid networking services. |
| [3 Storage](#3-storage) | No | Deploys [Storage Accounts](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview) (Blob and/or File) or [NetApp Files](https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction) storage services. |
| [4 Storage Cache](#4-storage-cache) | Yes | Deploys [HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) for highly-available and scalable file caching. |
| [5 Compute Image](#5-compute-image) | No | Deploys [Compute Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries) images that are custom built via [Image Builder](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview) service. |
| [6 Compute Scheduler](#6-compute-scheduler) | No | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines) for job and task scheduling across render farms. |
| [7 Compute Farm](#7-compute-farm) | Yes | Deploys [Virtual Machine Scale Sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview) for [Linux](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) and/or [Windows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) render farms. |
| [8 Compute Workstation](#8-compute-workstation) | No | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines) for [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) remote artist workstations. |
| [9 Monitor](#9-monitor) | No | Deploys [Monitor Private Link](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security) with [Private DNS](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) and [Private Endpoint](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview) integration. |
| [10 Render](#10-render) | No | Submit render farm jobs from [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) remote artist workstations. |

To manage deployment of the Azure Artist Anywhere solution from your local workstation, the following prerequisite steps are required.
1. Make sure the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) is installed locally and accessible in your path environment variable.
1. Make sure the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli) is installed locally and accessible in your path environment variable.
1. Run `az account show` to ensure your current Azure subscription session context is set as expected. Verify the `id` property.<br/>To change your current Azure subscription session context, run `az account set --subscription <subscriptionId>`
1. Download the Azure rendering end-to-end (e2e) solution example source files via the following GitHub directory link
   * https://downgit.github.io/#/home?url=https://github.com/Azure/Avere/tree/main/src/terraform/examples/e2e
   * Unzip the downloaded `e2e.zip` file to your local home directory (`~/`).<br/>Note that all local source file references below are relative to `~/e2e/`

## 0 Global

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/0.global`
1. Review and edit the config values in `variables.tf` for your deployment
1. Review and edit the config values in `backend.config` for your deployment

## 1 Security

*Before deploying the Security module*, the following built-in [Azure Role-Based Access Control (RBAC)](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview) role *is required for the current user* to enable creation of Azure Key Vault secrets, certificates and keys.
* *Key Vault Administartor* (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-administrator)

For Azure role assignment instructions, refer to either the Azure [portal](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal), [CLI](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli) or [PowerShell](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell) documents.

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/1.security`
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)
1. Use the [Azure portal to update your Key Vault secret values](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal) (`GatewayConnection`, `AdminPassword`)

## 2 Network

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/2.network`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 3 Storage

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/3.storage`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 4 Storage Cache

*Before deploying the Storage Cache module*, download the latest [Terraform Avere provider](https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere) to your local workstation using the following `Bash` / `Linux` commands or `PowerShell` / `Windows` commands.

`Bash` / `Linux`
```
latestVersion=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name)
downloadUrl=https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere
localDirectory=~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/${latestVersion:1}/linux_amd64
mkdir -p $localDirectory
cd $localDirectory
curl -L $downloadUrl -o terraform-provider-avere_$latestVersion
chmod 755 terraform-provider-avere_$latestVersion
cd ~/
```

`PowerShell` / `Windows`
```
$latestVersion = (Invoke-WebRequest -Uri https://api.github.com/repos/Azure/Avere/releases/latest | ConvertFrom-Json).tag_name
$downloadUrl = "https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere.exe"
$localDirectory = "$Env:AppData\terraform.d\plugins\registry.terraform.io\hashicorp\avere\$($latestVersion.Substring(1))\windows_amd64"
New-Item -ItemType Directory -Path $localDirectory -Force
Set-Location $localDirectory
Invoke-WebRequest $downloadUrl -OutFile terraform-provider-avere_$latestVersion.exe
Set-Location ~/
```

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/4.storage.cache`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. For [Avere vFXT](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) deployment only,
   * Make sure the [Avere vFXT image terms have been accepted](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms) (only required once per Azure subscription)
   * Make sure you have at least 96 (32 x 3) cores quota available for [Esv3](https://docs.microsoft.com/en-us/azure/virtual-machines/ev3-esv3-series#esv3-series) machines in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 5 Compute Image

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/5.compute.image`
1. Review and edit the config values in `config.auto.tfvars` for your deployment. Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)
1. After successful image template deployment, use the Azure portal or [CLI](https://docs.microsoft.com/en-us/cli/azure/image/builder?view=azure-cli-latest#az_image_builder_run) to start image build runs

## 6 Compute Scheduler

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/6.compute.scheduler`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the "imageId" config has the correct value for an image in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 7 Compute Farm

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/7.compute.farm`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the "imageId" config has the correct value for an image in your Azure subscription.
   * Make sure the "fileSystemMounts" config has the correct values (e.g., storage account name).
   * Make sure module [4 Storage Cache](#4-storage-cache) is deployed and *Running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 8 Compute Workstation

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/8.compute.workstation`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the "imageId" config has the correct value for an image in your Azure subscription.
   * Make sure the "fileSystemMounts" config has the correct values (e.g., storage cache mount).
   * Make sure module [4 Storage Cache](#4-storage-cache) is deployed and *Running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 9 Monitor

### Deployment Steps

1. Open a local shell (Bash or PowerShell) and run `cd ~/e2e/9.monitor`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 10 Render

Now that deployment of the Azure Artist Anywhere solution is complete, this section provides render job submission examples via the general purpose Deadline [SubmitCommandLineJob](https://docs.thinkboxsoftware.com/products/deadline/10.1/1_User%20Manual/manual/command-line-arguments-jobs.html#submitcommandlinejob) API.

### Linux Render Farm (*the following example jobs can be submitted from a Linux or Windows workstation*)

```
deadlinecommand -SubmitCommandLineJob -name ellie -executable blender -arguments "-b -y /mnt/show/read/blender/ellie/3.0.blend --render-output /mnt/show/write/blender/ellie/output/ --render-frame <STARTFRAME>..<ENDFRAME>"
```

```
deadlinecommand -SubmitCommandLineJob -name amy.frames -executable blender -arguments "-b -y /mnt/show/read/blender/amy/rain_restaurant.blend --render-output /mnt/show/write/blender/amy/output/ --engine CYCLES --render-frame <STARTFRAME>..<ENDFRAME>" -frames 100-280 -chunksize 19
```

```
deadlinecommand -SubmitCommandLineJob -name amy.video -executable blender -arguments "-b -y /mnt/show/read/blender/amy/rain_restaurant.blend --render-output /mnt/show/write/blender/amy/output/ --engine CYCLES --render-format FFMPEG --render-anim" -frames 100-280 -chunksize 19
```

### Windows Render Farm (*the following example jobs can be submitted from a Linux or Windows workstation*)

```
deadlinecommand -SubmitCommandLineJob -name ellie -executable blender.exe -arguments "-b -y R:\blender\ellie\3.0.blend --render-output W:\blender\ellie\output\ --render-frame <STARTFRAME>..<ENDFRAME>"
```

```
deadlinecommand -SubmitCommandLineJob -name amy.frames -executable blender.exe -arguments "-b -y R:\blender\amy\rain_restaurant.blend --render-output W:\blender\amy\output\ --engine CYCLES --render-frame <STARTFRAME>..<ENDFRAME>" -frames 100-280 -chunksize 19
```

```
deadlinecommand -SubmitCommandLineJob -name amy.video -executable blender.exe -arguments "-b -y R:\blender\amy\rain_restaurant.blend --render-output W:\blender\amy\output\ --engine CYCLES --render-format FFMPEG --render-anim" -frames 100-280 -chunksize 19
```

If you have any questions or issues, please contact rick.shahid@microsoft.com
