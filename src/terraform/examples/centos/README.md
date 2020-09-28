# Create and Upload CentOS 7.x for Rendering Studios

These instructions supplement Azure documentation to create and upload an CentOS image and have considerations for the locked down environment of rendering studios.  It is highly recommended to start from the CentOS Azure stock images, and use the [image capture process](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image), but these instructions will provide guidance when this is not possible.

Here are the steps to build an image on-premises, upload to Azure, and deploy on Azure:

1. [Build the Custom Image](#build-the-custom-image)
1. [Prepare Image Size and Format for Azure](#prepare-image-size-and-format-for-azure)
1. [Upload Image](#upload-image)
1. [Create and Deploy Image](#create-and-deploy-image)
1. [Next Steps: Image Capture and Scaling](#next-steps-image-capture-and-scaling)

All of these instructions may be automated through az cli or the [Terraform Azure Provider](https://www.terraform.io/docs/providers/azurerm/).

# Build the Custom Image

Use your current environment to create a CentOS virtual machine image CentOS using the following instructions: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-centos.

Here are the important tips to follow when building the image:

* remove swap partition, as this will eat up your ops on your OS disk.  As an alternative, the Azure Linux Agent (waagent) can configure a swap partition as outlined in the setup instructions

* if you want to enable cloud-init, please follow the instructions for [preparing CentOS for cloud-init on Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/cloudinit-prepare-custom-image#preparing-rhel-76--centos-76)

* if you want to run without the WAAgent (and no cloud-init) follow the instructions around [Creating generalized images without a provisioning agent](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/no-agent)

# Prepare Image Size and Format for Azure

Azure requires the following image file requirements:
1. fixed VHD with a ".vhd extension
1. byte aligned to 1MB chunks + a 512K footer

The `qemu-img` command can do the conversion and resizing [described here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic#resizing-vhds).  **Important note** when using `qemu-img` ensure you use the option `force_size`, to get the correct size.

To make upload easy start with a small image, and it can be resized on the cloud using the [disk_size_gb](https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine.html#disk_size_gb) property in terraform.

# Upload Image

Once you have prepared the fixed VHD byte aligned to 1MB chunks + a 512K footer, here are 3 options for upload and image creation:

1. [Internet Restricted: upload via a private endpoint connection enabled storage account](#internet-restricted-upload-via-a-private-endpoint-connection-enabled-storage-account) - for internet restricted environments, this approach enables the upload through a private endpoint ip address on your VNVET.

1. [Upload via a Managed Disk](#upload-the-custom-image-via-a-managed-disk) - this option does not require a storage account for image creation.

1. [Upload via Azure Storage Account](#upload-the-custom-image-via-a-storage-account) - this approach is useful from low bandwidth, low latency connections, where you are having trouble uploading to the Managed disk URL.

## Internet Restricted: upload via a private endpoint connection enabled storage account

Here are the steps to protect an Azure storage account:

### Create Private Storage Account and create SAS URL to container:
1. create storage account
2. create a container 'vhd'
3. browse to FQDN to find its FQDN and Private IP
   eg. STORAGEACCOUNT.blob.core.windows.net, 10.0.0.36

From the cloud shell generate the SAS URL:

```bash
az storage container generate-sas --account-name STORAGEACCOUNT --https-only --permissions acdlrw --start 2020-09-24T00:00:00Z --expiry 2020-09-26T00:00:00Z --name vhd --output tsv
```
 
### From On-Prem: Prepare Image and Resize, upload image to storage account using Az copy
From on-prem, populate your /etc/hosts or DNS with the IP address representing the newly created endpoint above

```bash
10.0.0.36 STORAGEACCOUNT.blob.core.windows.net
```
Next copy the blob to the private endpoint using a concatenateion of the blob url and SAS url created above:
```bash
# copy the blob
azcopy copy /mnt/resource/centos74.vhd 'https://STORAGEACCOUNT.blob.core.windows.net/vhd?st=2020-09-24T00%3A00%3A00Z&se=2020-09-26T00%3A00%3A00Z&sp=racwdl&spr=https&sv=2018-11-09&sr=c&sig=sLnnKUDc1/630ksckyDHqnSvPMsTAD6Ozcq7mlAN8Rg%3D'
```

From Portal: create and deploy image
# create the image
az image create --location eastus --resource-group RESOURCE_GROUP --name newimage --os-type Linux --source https://STORAGEACCOUNT.blob.core.windows.net/vhd/centos74.vhd

Alternatively you can wire up a [managed disk as a private endpoint as described here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/disks-export-import-private-links-cli).

## Upload the Custom Image via a managed disk

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
azcopy copy centos.vhd "SAS_URI"
```
3. revoke access
```bash
az disk revoke-access -n centosmanagedimage -g RESOURCE_GROUP_NAME
```

With the managed disk you can now create the image, and delete the managed disk:

```bash
az image create --location LOCATION --resource-group RESOURCE_GROUP_NAME --name IMAGE_NAME --os-type Linux --source MANAGED_DISK_ID
```

## Upload the Custom Image via a storage account

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
az storage container create --account-name STORAGE_ACCOUNT_NAME --name vhd
```

Next upload the image:
1. install [azcopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10)
2. login to [azcopy] with `azcopy login` command
3. execute the following command to upload to the storage account:
```bash
azcopy copy centos.vhd https://STORAGE_ACCOUNT_NAME.blob.core.windows.net/vhd/centos.vhd
```

Once uploaded create the image using the following command:
```bash
az image create --location LOCATION --resource-group RESOURCE_GROUP_NAME --name IMAGE_NAME --os-type Linux --source https://STORAGE_ACCOUNT_NAME.blob.core.windows.net/vhd/centos.vhd
```

Once the image is created, you can now delete the storage account:
```bash
az storage account delete --name STORAGE_ACCOUNT_NAME
```

# Create and Deploy Image

Using the `main.tf` in this folder, create the deployment.

# Next Steps: Image Capture

Now that you have the image in cloud you may want to refine it, and that is done in the capture phase described in the following document: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image.  Step 2 of the document provides the automation commands, but these commands of deallocate, generalize, and image create can all be done by clicking the "catpure" button on the VM page in the portal.
