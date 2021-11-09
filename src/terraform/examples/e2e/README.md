# Azure Artist Anywhere (AAA) Rendering Solution

This folder contains the end-to-end example configuration and automated deployment framework for the [Azure Artist Anywhere (AAA) rendering solution architecture](https://github.com/Azure/Avere/blob/main/src/terraform/burstrenderarchitecture.png). By leveraging the [Azure First Render Pilot](../securedimage/Azure%20First%20Render%20Pilot.pdf) process along with [Terraform](https://www.terraform.io/) across the following deployment modules, your existing pipeline can be extended via [Azure HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) to enable rendering at scale without moving your asset storage.

| Module | Description |
| :----- | :---------- |
| [0 Security](#0-security) | Deploys [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview) and [Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) with Terraform state management [Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction). |
| [1 Network](#1-network) | Deploys [Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) with [VPN](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) or [ExpressRoute](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways) hybrid networking services. |
| [2 Storage](#2-storage) | Deploys [Storage Accounts](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview) (Blob or File) or [NetApp Files](https://docs.microsoft.com/en-us/azure/azure-netapp-files/azure-netapp-files-introduction) storage services. |
| [3 Storage Cache](#3-storage-cache) | Deploys [HPC Cache](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview) or [Avere vFXT](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-overview) for highly-available and scalable file caching. |
| [4 Compute Image](#4-compute-image) | Deploys [Shared Image Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries) with automated image building via [Image Builder](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview). |
| [5 Compute Scheduler](#5-compute-scheduler) | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/) for distributed job scheduling across a render farm. |
| [6 Compute Farm](#6-compute-farm) | Deploys [Virtual Machine Scale Sets](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview) for [Linux](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) or [Windows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) render farms. |
| [7 Compute Workstation](#7-compute-workstation) | Deploys [Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/) for [Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/overview) and/or [Windows](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/overview) artist workstations. |
| [Render Job Submission](#render-job-submission) | Submit render job from the perspective of a remote artist workstation. |

To manage the Azure rendering solution infrastructure from your local workstation, the following prerequisite steps are required.
1. Make sure the [Terraform CLI](https://www.terraform.io/downloads.html) is downloaded locally. Version 1.0.10 (or higher) is required.
1. Make sure the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) is installed locally. The latest version is 2.29.2 as of October, 2021.
1. Make sure that [Git](https://git-scm.com/downloads) is installed locally. The latest version is 2.33.1 as of October, 2021.
1. Run `az account show` to ensure that your target Azure subscription context is set appropriately. If requested, run `az login` 
1. To change your target Azure subscription context, run `az account set --subscription YOUR_SUBSCRIPTION_ID`
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

## 0 Security

*Before deploying the Security module*, the following built-in Azure roles are required for the current user to create KeyVault secrets and keys, respectively
* "Key Vault Secrets Officer" - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-officer
* "Key Vault Crypto Officer"  - https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer

For Azure role assignment instructions, refer to either the Azure [portal](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal), [CLI](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli) or [PowerShell](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell) documents.

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/global`
1. Edit the `regionName` config value in `variables.tf` using your favorite text editor
1. Run `cd ~/tf/src/terraform/examples/e2e/0.security`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module
1. Use the [Azure portal to update your Key Vault secrets](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-portal) (`GatewayConnection`, `AdminPassword`)
1. Run `cd ~/tf/src/terraform/examples/e2e`
1. Edit the config values in `backend.config` to match the config values that you set in `config.auto.tfvars`
1. Run `cd ~/tf/src/terraform/examples/e2e/global`
1. Edit the config values in `variables.tf` to match the config values that you set in `config.auto.tfvars`

## 1 Network

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/1.network`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor.
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module

## 2 Storage

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/2.storage`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor.
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module

## 3 Storage Cache

*Before deploying the Storage Cache module*, download the latest [Terraform Avere provider](https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere) using the following commands.

`Bash` / `Linux`
```
latestVersion=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name)
downloadUrl=https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere
localDirectory=~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/${latestVersion:1}/linux_amd64
mkdir -p $localDirectory
cd $localDirectory
curl -L $downloadUrl -o terraform-provider-avere_$latestVersion
chmod 755 terraform-provider-avere_$latestVersion
```

`PowerShell` / `Windows`
```
$latestVersion = (Invoke-WebRequest -Uri https://api.github.com/repos/Azure/Avere/releases/latest | ConvertFrom-Json).tag_name
$downloadUrl = "https://github.com/Azure/Avere/releases/download/$latestVersion/terraform-provider-avere.exe"
$localDirectory = "$Env:AppData\terraform.d\plugins\registry.terraform.io\hashicorp\avere\$($latestVersion.Substring(1))\windows_amd64"
New-Item -Path $localDirectory -ItemType Directory -Force
Set-Location $localDirectory
Invoke-WebRequest $downloadUrl -OutFile terraform-provider-avere_$latestVersion.exe
```

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/3.storage.cache`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor.
1. For Avere vFXT deployment, make sure the [Avere vFXT image terms have been accepted](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms) (only required once per Azure subscription)
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module

## 4 Compute Image

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/4.compute.image`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor. Make sure you have sufficient compute cores quota available on your Azure subscription for the selected virtual machine size(s).
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module
1. After successful deployment, use the Azure portal or CLI to start image template build processes

## 5 Compute Scheduler

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/5.compute.scheduler`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor. Make sure you have sufficient compute cores quota available on your Azure subscription for the selected virtual machine size(s).
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module

## 6 Compute Farm

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/6.compute.farm`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor. Make sure you have sufficient compute Spot cores quota available on your Azure subscription.
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module

## 7 Compute Workstation

### Deployment Steps (*via a local Bash or PowerShell command shell*)

1. Run `cd ~/tf/src/terraform/examples/e2e/7.compute.workstation`
1. Edit the config values in `config.auto.tfvars` using your favorite text editor. Make sure you have sufficient compute cores quota available on your Azure subscription for the selected virtual machine size(s).
1. Run `terraform init -backend-config ../backend.config` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the deployment (add, change and/or destroy) of the Azure resources in this module

## Render Job Submission

Now that the Azure Artist Anywhere solution deployment is complete, this next section will walk through the render job submission process. For this example, we have deployed the render farm in Azure on CentOS 7.8 and the artist workstation in Azure on Windows 10. We are also using Teradici PCoIP for remote access to the artist workstation over Azure VPN.

*TBD*

If you have any questions or issues, please contact rick.shahid@microsoft.com
