# Azure Artist Anywhere (AAA) Rendering Solution

This folder contains the end-to-end modular framework for automated deployment of the [Azure Artist Anywhere (AAA) rendering architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). By extending your rendering pipeline with [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview), you can enable remote artists across [Azure Regions](https://azure.microsoft.com/en-us/global-infrastructure/geographies) and scale your Azure render farm. You can choose to connect your on-premises asset storage via [Azure Hybrid Networking](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking) and/or deploy Azure (multi-regional) storage.

The following core principles are implemented throughout this Azure rendering solution framework.
* Incorporation of security best practices ([Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview), [Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview), etc.) 
* Separation of module deployment configuration (**config.auto.tfvars**) and code (**main.tf**) files.
* While modules [0 Global](#0-global) and [1 Security](#1-security) *are* required steps to setup the deployment framework,<br/>deployment of each subsequent module in a linear sequence is *not* required. For example,<br/>module [2 Network](#2-network) is *not* a requirement if you have an existing [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) deployed.

| Module | Description |
| :----- | :---------- |
| [0 Global](#0-global) | Defines global variables and Terraform backend configuration for the solution. |
| [1 Security](#1-security) | Deploys [Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview), [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview) and [Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction) for Terraform state files. |
| [2 Network](#2-network) | Deploys [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) with [VPN](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways) hybrid networking services. |
| [3 Storage](#3-storage) | Deploys [Storage Accounts](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview) (Blob or File), [NetApp Files](https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction) or [Hammerspace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/hammerspace.hammerspace) storage. |
| [4 Storage Cache](#4-storage-cache) | Deploys [HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) for highly-available and scalable file caching. |
| [5 Compute Image](#5-compute-image) | Deploys [Compute Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries) images that are custom built via [Image Builder](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview) service. |
| [6 Compute Scheduler](#6-compute-scheduler) | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines) for distributed job scheduling across a render farm. |
| [7 Compute Farm](#7-compute-farm) | Deploys [Virtual Machine Scale Sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview) for [Linux](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) or [Windows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) render farms. |
| [8 Compute Workstation](#8-compute-workstation) | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines) for [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) artist workstations. |
| [9 Monitor](#9-monitor) | Deploys [Monitor Private Link](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security) with [Private DNS](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) and [Private Endpoint](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview) integration. |
| [10 Render](#10-render) | Submit render farm jobs from [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) artist workstations. |

To manage deployment of the Azure Artist Anywhere solution from your local workstation, the following prerequisite steps are required.
1. Make sure the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli) (v1.1.6 or higher) is downloaded locally and accessible in your path environment variable.
1. Make sure the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) is installed locally and accessible in your path environment variable.
1. Make sure [Git](https://git-scm.com/downloads) is installed locally.
1. Run `az account show` to ensure that your current Azure subscription session context is set appropriately. To change your current Azure subscription session context, run `az account set --subscription YOUR_SUBSCRIPTION_ID`
1. Download the Azure rendering solution Terraform examples GitHub repository via the following commands.
   ```
   mkdir tf
   cd tf
   git init
   git remote add origin -f https://github.com/Azure/Avere.git
   git config core.sparsecheckout true
   echo "src/terraform/*" >> .git/info/sparse-checkout
   git pull origin main
   ```

## 0 Global

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/0.global`
1. Review and edit the config values in `variables.tf` for your deployment
1. Review and edit the config values in `backend.config` for your deployment

## 1 Security

*Before deploying the Security module*, the following built-in Azure roles *must be assigned to the current user* to enable creation of KeyVault secrets, certificates and keys, respectively.
* *Key Vault Secrets Officer* (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-officer)
* *Key Vault Certificates Officer* (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer)
* *Key Vault Crypto Officer*  (https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer)

For Azure role assignment instructions, refer to either the Azure [portal](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal), [CLI](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli) or [PowerShell](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell) documents.

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/1.security`
1. Review and edit the config values in `config.auto.tfvars` for your deployment
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)
1. Use the [Azure portal to update your Key Vault secret values](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal) (`GatewayConnection`, `AdminPassword`)

## 2 Network

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/2.network`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 3 Storage

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/3.storage`
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
New-Item -Path $localDirectory -ItemType Directory -Force
Set-Location $localDirectory
Invoke-WebRequest $downloadUrl -OutFile terraform-provider-avere_$latestVersion.exe
Set-Location ~/
```

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/4.storage.cache`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. *For Avere vFXT deployment only*, make sure the [Avere vFXT image terms have been accepted](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms) (only required once per Azure subscription)
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 5 Compute Image

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/5.compute.image`
1. Review and edit the config values in `config.auto.tfvars` for your deployment. Make sure you have sufficient compute cores quota available on your Azure subscription for each configured virtual machine size.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)
1. After successful image template deployment, use the Azure portal or [CLI](https://docs.microsoft.com/en-us/cli/azure/image/builder?view=azure-cli-latest#az_image_builder_run) to start image build runs

## 6 Compute Scheduler

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/6.compute.scheduler`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the "imageId" config has the correct value for an image in your Azure subscription.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 7 Compute Farm

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/7.compute.farm`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute (*Spot*) cores quota available in your Azure subscription.
   * Make sure the "imageId" config has the correct value for an image in your Azure subscription.
   * Make sure the "fileSystemMounts" config has the correct values (e.g., storage account name).
   * Make sure module [4 Storage Cache](#4-storage-cache) is deployed and *Running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 8 Compute Workstation

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/8.compute.workstation`
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
   * Make sure you have sufficient compute cores quota available in your Azure subscription.
   * Make sure the "imageId" config has the correct value for an image in your Azure subscription.
   * Make sure the "fileSystemMounts" config has the correct values (e.g., storage cache mount).
   * Make sure module [4 Storage Cache](#4-storage-cache) is deployed and *Running* before deploying this module.
1. Run `terraform init -backend-config ../0.global/backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

## 9 Monitor

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/9.monitor`
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
