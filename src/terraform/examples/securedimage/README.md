# Secured Image

This example shows an Azure administrator how to take an on-prem Ubuntu image, upload it to Azure, and then create a virtual machine with it.

Once the image is created, this shows how to provide minimal RBAC access for an Azure User to deploy and use the image.

These instructions are useful for understanding the security mechanisms of Azure and useful for testing a custom image before the VPN or express route is ready.

![The architecture](architecture.png)

## Build the custom image By Administrator

Follow the instructions to build a custom image:
* Create Ubuntu from disk: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu.  Please note that it is highly recommended to start from the ubuntu Azure images provided on the [create-upload-ubuntu page](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu).
* before running `waagent -force -deprovision`, as root run the script `fixubuntuimage.sh`  to correctly setup grub and cloud-init.  Without running this, the VM will not get to Running state.

Tips:
* it is highly recommended to start from the ubuntu Azure images provided on the [create-upload-ubuntu page](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu).
* If using vmdk images, you will need to convert to a fixed VHD.  One way to do this is with [MVMC](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn873998(v=ws.11)?redirectedfrom=MSDN) and here is the [MVMC download page](https://www.microsoft.com/en-us/download/details.aspx?id=42497).  Alternatively, you can convert using [qemu as described here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic#resizing-vhds).
* start with a small vhd to make upload easy, and it can be resized on the cloud.

## Upload the Custom Image via a managed disk By Administrator

These instructions are based on https://docs.microsoft.com/en-us/azure/virtual-machines/linux/disks-upload-vhd-to-managed-disk-cli.

First prepare the disk and get a write SAS (steps 1 and 2, can be replaced with browse to https://shell.azure.com):

1. install [az cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
2. login to az cli with
```bash
az --login
```
3. if you have more than one subscription, set your subscription with:
```bash
az account set --subscription SUBSCRIPTIONID
```
4. create a resource group to hold the managed disk and images:
```bash
az group create --location LOCATION --name RESOURCE_GROUP_NAME
```
5. get the size of your VHD via `ls -l` or `dir` commands, and run the following command to create the vhd:
```bash
az disk create -n DISK_NAME --location LOCATION --resource-group RESOURCE_GROUP_NAME --for-upload --upload-size-bytes SIZE_IN_BYTES --sku standard_lrs
```
6. get a 1 hour SAS uri for upload
```bash
az disk grant-access -n DISK_NAME --resource-group RESOURCE_GROUP_NAME --access-level Write --duration-in-seconds 3600
```

With the SAS uri, you can now copy your VHD:
1. install [azcopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10)
2. upload the vhd:
```bash
# quote the SAS URI so the special characters do not get interpreted by the shell
azcopy copy ubuntu.vhd "SAS_URI"
```
3. revoke access
```bash

```

With the managed disk you can now create the image, and delete the managed disk:
<!--
TODO - add remaining instructions
-->

## Upload the Custom Image via a storage account By Administrator

<!--
TODO - update with no storage account
-->

Once the VM is created and shutdown, ensure you convert the image to a fixed VHD using [the hyper-v instructions](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image) or [qemu](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic#resizing-vhds). Once you have a fixed VHD it is ready for upload.

First prepare the storage account and container:

1. install [az cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
2. login to az cli with
```bash
az --login
```
3. if you have more than one subscription, set your subscription with:
```bash
az account set --subscription SUBSCRIPTIONID
```
4. create a resource group to hold the storage account and images:
```bash
az group create --location LOCATION --name RESOURCE_GROUP_NAME
```
5. create a storage account to hold the vhd:
```bash
az storage account create --location LOCATION --resource-group RESOURCE_GROUP_NAME --name STORAGE_ACCOUNT_NAME --sku Standard_LRS
```
6. create a container to hold the vhds:
```bash
--location LOCATION --resource-group RESOURCE_GROUP_NAME
az storage container create --account-name STORAGE_ACCOUNT_NAME --name vhd
```

Next upload the image:
1. install [azcopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10)
2. login to [azcopy] with `azcopy login` command
3. execute the following command to upload to the storage account:
```bash
azcopy copy ubuntu.vhd https://anhowevhd.blob.core.windows.net/vhd/ubuntu.vhd
```

Once uploaded create the image using the following command:
```bash
az image create --location LOCATION --resource-group RESOURCE_GROUP_NAME --name IMAGE_NAME --os-type Linux --source https://STORAGE_ACCOUNT_NAME.blob.core.windows.net/vhd/ubuntu.vhd
```

Once the image is created, you can now delete the storage account:
```bash
az storage account delete --name STORAGE_ACCOUNT_NAME
```

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

## Deployment Instructions By Contributor

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