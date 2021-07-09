# CentOS Rendering End-to-End

This folder contains all the automation to configure all infrastructure described in the [first render pilot](../securedimage/Azure%20First%20Render%20Pilot.pdf) for a CentOS system.  A simulated on-premises environment is provided for experimentation without using a real on-premises environment.

![The architecture](../../../../docs/images/terraform/centose2e.png)

## Terraform Project Organization

There are multilple ways to organize and structure Terraform.  The approach that seemed to strike the right balance between security and complexity and Terraform best practices is outlined in [Terraform Structures and Layouts by Laura Martin](https://www.surminus.com/blog/terraform-structures-and-layouts/).

The organization principles are as follows:
1. Major Infrastructure Groups that share a similar life cycle are in their own folder
1. Security is first priority.  This is achieved using a keyvault, and storing terraform state in a storage account.
1. Configuration is captured in "config.* files".

When deploying to multiple regions there are two approaches that are [debated in the Terraform community](https://www.reddit.com/r/Terraform/comments/o7hch1/what_folder_structure_do_you_use_for_terraform/) each with advantages and disadvantages:
1. **Replicate the folders for each environment** - the first approach is to replicate the folders for each environment.  This ensure that each environment and associated configuration lives on its own.  The downside is that there is a lot of replication of code, but the upside is that human error with "terraform apply" does not overwrite the wrong environment.
2. **Workspaces** - Use [Terraform workspaces](https://www.terraform.io/docs/cloud/guides/recommended-practices/part3.3.html#3-design-your-organization-s-workspace-structure).  In this approach, you would have different `*.tfvars` and `*.backend` files for the environment.  For example `eastus.tfvars` and `eastus.tfvars` for east us and `westus2.tfvars` and `westus2.tfvars` for west us2.  The disadvantage of this approach is that human error in setting the wrong environment or specifying the wrong tfvars file, will overwrite the infrastructure in wrong environment.

## Pre-requisites

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com, and choose a Bash shell.

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

### 0. Security

To ensure security, Terraform requires a keyvault, and a storage account to hold the tfstate files.

The keyvault stores all the secrets used in this example.  Be sure to configure the following Secrets with keys:
* `vpngatewaykey` - this is the subnet to contain the VPN gateway
* `virtualmachine` - this configures the password for the virtual machines used in this example
* `AvereCache` - this configures the secret to be used with the Avere Cache

The tfstate files contain secrets, so it is recommended to use a protected backend for storing of these files.  For this example, an Azure Storage Account is deployed and used to store the tfstate files.  Here are good articles related to terraform backends:
1. **Backends** - https://www.terraform.io/docs/language/settings/backends/index.html
1. **AzureRM Backend** - https://www.terraform.io/docs/language/settings/backends/azurerm.html

### Steps to Deploy

1. Before deploying, ensure you have Role `Key Vault Secrets Officer`.  To do this, open https://portal.azure.com, and browse to Subscriptions=>Access Control (IAM) and add "Key Vault Secrets Officer" to your id.
1. `cd ~/tf/src/terraform/examples/centos-e2e/0.keyvault`
1. `code config.tfvars` and edit the values to your desired values.
1. `terraform init` and `terraform apply -auto-approve`
1. once deployed, browse to the keyvault in the portal and update the secrets for each of the three keys.
1. **Important** `code ../config.backend` to edit and update with the output variables.  This will be used to store the tfstate.
1. **Important** `code ../config.tfvars` to edit and update with location and keyvault id.  This will be used for secret retrieval.

## 1.Network

This sets up a VNET with the following subnets:

1. GatewaySubnet
2. Cache
3. Render Nodes

### Steps to Deploy

1. `cd ~/tf/src/terraform/examples/centos-e2e/1.network`
1. `code config.auto.tfvars` and edit the variables
1. `terraform init -backend-config ../config.backend`
1. `terraform apply -auto-approve -var-file ../config.tfvars`

### On-premises Environment

If you do not have an on-premises environment, deploy the [simulated on-prem environment](Appendix.A-SimulatedOnPrem/).  Otherwise skip this step.

Otherwise, the on-prem environment must have VPN or ExpressRoute connectivity to Azure with non-overlapping subnet ranges.  An NFS filer with the following access is required:
* `no_root_squash` - this is needed because HPC Cache or vFXT works at the root level
* `rw` - read/write is needed for the HPC Cache or vFXT to write files
* **ip range is open** - ensure the HPC Cache or vFXT subnet is specified in the export.  Also, if any render clients are writing around, you will also need to open up the subnet range of the render clients, otherwise this is not needed.

### Steps to Deploy

For deployment of the simulated environment, consider a different region from rest of the example to simulate a higher latency.

1. `cd ~/tf/src/terraform/examples/centos-e2e/Appendix.A-SimulatedOnPrem`
1. `code config.auto.tfvars` and edit the values to your desired values.
1. `terraform init -backend-config ../config.backend`
1. `terraform apply -auto-approve -var-file ../config.tfvars`

## 1.network.vpnconnection

This step connects the on-prem gateway with the cloud gateway.

1. `cd ~/tf/src/terraform/examples/centos-e2e/1.network.vpnconnection`
1. `code config.tfvars` and edit the values to your desired values.
1. `code main.tf` and edit the variables at the top
1. `terraform init` and `terraform apply -auto-approve`

## 3. CentOS Stock

This step deploys a stock image, and is used for creation of a custom image.

### Deploy instructructions

1. in cloud shell, `cd ~/tf/src/terraform/examples/centos-e2e/3.centosstock`
1. `code main.tf` and edit the variables at the top
1. `terraform init` and `terraform apply -auto-approve`
1. log into the VM and configure before creating the VM

### Capture instructions

Once you have deployed the stock VM, login and configure, and then run the following two steps ([more info](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image)):
1. on VM, run `sudo waagent -deprovision+user` and exit
2. in portal click the "Capture" button, and capture to a separate resource group, and don't delete the VM.
3. after VM is captured, `terraform deploy` to remove the VM

## 4. CentOS Image

## 5. Cache - HPC Cache

This step mounts the NFS filer on-prem.
1. in cloud shell, `cd ~/tf/src/terraform/examples/centos-e2e/5.cache/hpccache`
1. `code main.tf` and edit the variables at the top
1. `terraform init` and `terraform apply -auto-approve`

## 6. VMSS

## 7. Threat Modeling

