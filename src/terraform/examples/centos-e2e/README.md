# CentOS Rendering End-to-End

This folder contains all the automation to configure all infrastructure described in the [first render pilot](../securedimage/Azure%20First%20Render%20Pilot.pdf).

## Deployment Instructions

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

## 1. Azure Key Vault

The keyvault stores all the secrets used in this example.  Be sure to configure the following Secrets with keys:
* `vpngatewaykey` - this is the subnet to contain the VPN gateway
* `virtualmachine` - this configures the 
* `AvereCache` - this configures the secret to be used with the Avere Cache

### Steps to Deploy

1. Before deploying, ensure you have Role `Key Vault Secrets Officer`.  To do this, open https://portal.azure.com, and browse to Subscriptions=>Acccess Control (IAM) and add "Key Vault Secrets Officer" to your id.
1. back in cloud shell, `cd ~/tf/src/terraform/examples/centos-e2e/1.keyvault`
1. `code main.tf` and edit the variables at the top.  Once applied.
1. `terraform init` and `terraform apply -auto-approve`
1. once deployed, browse to the keyvault in the portal and update the secrets for each of the three keys.

## 2.1 Network

This sets up a VNET with the following subnets:

1. Gateway
2. Cache
3. Render Nodes

### Steps to Deploy

1. back in cloud shell, `cd ~/tf/src/terraform/examples/centos-e2e/2.1.network`
1. `code main.tf` and edit the variables at the top
1. `terraform init` and `terraform apply -auto-approve`

## 2.2 Simulated On Prem

This step creates a simulated on-premises network with a filer and jumpbox.

1. in cloud shell, `cd ~/tf/src/terraform/examples/centos-e2e/2.2.simulatedonprem`
1. `code main.tf` and edit the variables at the top
1. `terraform init` and `terraform apply -auto-approve`

## 2.3 VPN Connection

This step creates a simulated on-premises network with a filer and jumpbox.

1. in cloud shell, `cd ~/tf/src/terraform/examples/centos-e2e/2.3vpnconnection/simulatedonprem`
1. `code main.tf` and edit the variables at the top
1. `terraform init` and `terraform apply -auto-approve`

## 3. CentOS Stock

Once you have deployed the image, run the following two steps:
1. on VM, run `sudo waagent -deprovision+user` and exit
2. in portal click the "Capture" button, and capture to a separate resource group, and don't delete the VM.
3. after VM is captured, `terraform deploy` to remove the VM

## 4. CentOS Image

## 5. Cache

## 6. VMSS

## 7. Threat Modeling

