# Secured Image

This example shows an Azure administrator how to take an on-prem Ubuntu 18.04 image, upload it to Azure, and then provide access to a Contributor to create a virtual machine with it.

These instructions are useful for understanding the security mechanisms of Azure including [RBAC](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview), [governance enablement via Azure Policy](https://azure.microsoft.com/en-us/solutions/governance/), and [network security](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-overview).  These instructions are useful for testing a custom image before the VPN or express route is ready.

![The architecture](architecture.png)

The steps to for creation to deployment are the following:
1. [Build the custom image By Administrator](CreateUploadUbuntu.md#build-the-custom-image-by-administrator)
2. [Upload the Custom Image via a managed disk By Administrator](CreateUploadUbuntu.md#upload-the-custom-image-via-a-managed-disk-by-administrator)
3. [Create the access for the Contributor By Administrator](#create-the-access-for-the-contributor-by-administrator)
4. [Deployment Custom Image By Contributor](#deployment-custom-image-by-contributor)

## Create the access for the Contributor By Administrator

Here are the steps to lock down the contributor to the resource groups holding the VM and the custom image.

```bash
export SUBSCRIPTION=#YOUR SUBSCRIPTION
export TARGET_LOCATION=eastus # your target location
export VM_RESOURCE_GROUP=#the target VFXT resource group
export VHD_RESOURCE_GROUP=#the target VNET resource group
az account set --subscription $SUBSCRIPTION
az group create --location $TARGET_LOCATION --name $VFXT_RESOURCE_GROUP
# create the SP
az ad sp create-for-rbac --role "Virtual Machine Contributor" --scopes /subscriptions/$SUBSCRIPTION/resourceGroups/$VM_RESOURCE_GROUP
# save the output somewhere safe
export SP_APP_ID=#the appId of the Service Principal from the previous command
# assign the "Virtual Machine Contributor" and the "Avere Contributor" to the scope of the VNET resource group
az role assignment create --role "Virtual Machine Contributor" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$VHD_RESOURCE_GROUP --assignee $SP_APP_ID
###########################################################
# pass the SP details to the person installing the VM
# once complete, delete the SP with the following command:
#    az ad sp delete --id $SP_APP_ID
###########################################################
```

## Deployment Custom Image By Contributor

<!--
TODO - add comments to main.tf
TODO - add "resize" logic for OS disk
-->

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin master
```

4. `cd src/terraform/examples/securedimage`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the HPC Cache cluster

Once installed you will be able to login and use your custom image.

When you are done using the filer, you can destroy it by running `terraform destroy -auto-approve`.