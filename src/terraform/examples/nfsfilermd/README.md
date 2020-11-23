# Azure Terraform NFS based IaaS NAS Filer using a managed disk

This example shows how to use the nfs filer module to deploy Azure Terraform NFS based IaaS NAS Filer using a managed disk.

The mode `offline_mode` can be set to true to destroy the VM and downgrade the disk to standard to ensure maximum cost savings during when there is no demand.  Then  set `offline_mode` back to true to create the disk and get it running again.

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.  If you are installing into your own environment, you will need to follow the [instructions to setup terraform for the Azure environment](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure).

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription, and you will see an error similar to `azurerm_public_ip.vm is empty tuple`.

3. As a pre-requisite ensure you have a network and the ability to ssh to a private ip address.  If not deploy the [jumpbox example](../jumpbox/).

4. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin main
```

6. `cd src/terraform/examples/nfsfilermd`

7. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences

8. execute `terraform init` in the directory of `main.tf`.

9. execute `terraform apply -auto-approve` to build the nfs filer

Once installed you will be able to mount the nfs filer.

Test toggling the `offline_mode` variable to see that it destroys the VM and downgrades the disk when turned off.

When you are done using the filer, you can destroy it by running `terraform destroy -auto-approve`.

## Create copy of disk in same region

To create a copy of the disk in the same region run the following steps:

1. browse to https://shell.azure.com, and `cd src/terraform/examples/nfsfilermd` or the directory from which you created the nfsfiler.

1. `code main.tf` to edit the file

1.  set `offline_mode` to `true` to detach the disk and shutdown the VM

1.  run `terraform apply -auto-approve`.   This will detach the disk and shutdown the VM.

1. once shutdown, use the `list_disks_az_cli` output az cli command to get the ID of disk by run the following command.  For example, it will look similar to the following:

```bash
az disk list --query "[?resourceGroup=='FILER_RG'].id"
```

1. run the following command to make a copy of the disk in the same region:

```bash
export SOURCE_DISK_ID="REPLACE"
export SOURCE_DISK_ID="REPLACE"
export DISK_TARGET_RESOURCE_GROUP="REPLACE"
export DISK_TARGET_NAME="disk-copy"
export DISK_TARGET_SKU="Standard_LRS"
az disk create --source $SOURCE_DISK_ID -g $DISK_TARGET_RESOURCE_GROUP -n $DISK_TARGET_NAME --sku $DISK_TARGET_SKU
```

1. run the disk list command to get the disk ids:
```bash
az disk list --query "[?resourceGroup=='FILER_RG'].id"
```

## Create copy of disk in another region

To make a copy of the disk across region ensure the following are true:

1. The disk is detached from a VM.  Creating a copy of the disk will work.
1. The disk is a "standard_LRS" SKU.  This ensures the disk is transferred using the storage account specifications which have high throughput and IOPS.

Run the following script to copy the disk to another region:

```bash
# modify the below parameters
export SOURCE_DISK_ID="REPLACE"
export DISK_TARGET_REGION="REPLACE"
export DISK_TARGET_RESOURCE_GROUP="REPLACE"
export DISK_TARGET_NAME="backup-disk"

# create the remote disk and copy
export DISK_SIZE_BYTES=$(az disk list --query "[?id=='$SOURCE_DISK_ID'].diskSizeBytes | [0]" -otsv)
export DISK_TARGET_SKU=Standard_LRS
az group create --location $DISK_TARGET_REGION --name $DISK_TARGET_RESOURCE_GROUP
az disk create --upload-size-bytes $(expr $DISK_SIZE_BYTES + 512) --location $DISK_TARGET_REGION --resource-group $DISK_TARGET_RESOURCE_GROUP -n $DISK_TARGET_NAME --for-upload --sku $DISK_TARGET_SKU

export SOURCE_SAS_URL=$(az disk grant-access --id $SOURCE_DISK_ID --access-level Read --duration-in-seconds 7200 --query "accessSas" -otsv)
export TARGET_SAS_URL=$(az disk grant-access -n $DISK_TARGET_NAME --resource-group $DISK_TARGET_RESOURCE_GROUP --access-level Write --duration-in-seconds 7200 --query "accessSas" -otsv)

# copy the source disk to the destination
azcopy copy "$SOURCE_SAS_URL" "$TARGET_SAS_URL"

# revoke access on both disks
az disk revoke-access --id $SOURCE_DISK_ID
az disk revoke-access -n $DISK_TARGET_NAME --resource-group $DISK_TARGET_RESOURCE_GROUP
```

1. once complete, run the disk list command to get the new disk id:
```bash
az disk list --query "[?resourceGroup=='$DISK_TARGET_RESOURCE_GROUP'].id"
```
