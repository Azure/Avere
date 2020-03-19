# Create and Upload Ubuntu 18.04

These instructions supplement Azure documentation to create and upload an Ubuntu 18.04 image.  Tickets have been submitted to correct existing documentation, to obsolete this page.

## Build the custom image By Administrator

Follow the instructions to build a custom image:
1. Create Ubuntu from disk and stop at instruction `waagent -force -deprovision`: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu.  Please note that it is highly recommended to start from the ubuntu Azure images provided on the [create-upload-ubuntu page](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu).
2. before running `waagent -force -deprovision`, as root run the script [fixubuntuimage.sh](fixubuntuimage.sh)  to correctly setup grub and cloud-init.  Without running this, the VM will not get to Running state.
3. Complete process by running the remaining steps.

Tips:
* ensure the final image is a fixed VHD, byte aligned in 1MB chunks + a 512K footer
* it is highly recommended to start from the ubuntu Azure images provided on the [create-upload-ubuntu page](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu).
* If using vmdk images, you will need to convert to a fixed VHD.  One way to do this is with [MVMC](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn873998(v=ws.11)?redirectedfrom=MSDN) and here is the [MVMC download page](https://www.microsoft.com/en-us/download/details.aspx?id=42497).  Alternatively, you can convert using [qemu as described here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic#resizing-vhds).
* start with a small vhd to make upload easy, and it can be resized on the cloud using the [disk_size_gb](https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine.html#disk_size_gb) property in terraform.

Once you have prepared the VHD there are two choices for upload:
1. [Upload via a Managed Disk](#upload-the-custom-image-via-a-managed-disk-by-administrator) - this is the recommended way to upload as it does not require a storage account which can be another point of data exfiltration.
2. [Upload via Azure Storage Account](#upload-the-custom-image-via-a-storage-account-by-administrator) - this approach is useful from low bandwidth, low latency connections, where you are having trouble uploading to the Managed disk URL.

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
az disk revoke-access -n ubuntumanagedimage -g anhowemanagedimage
```

With the managed disk you can now create the image, and delete the managed disk:

```bash
az image create --location LOCATION --resource-group RESOURCE_GROUP_NAME --name IMAGE_NAME --os-type Linux --source MANAGED_DISK_ID
```

## Upload the Custom Image via a storage account By Administrator

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