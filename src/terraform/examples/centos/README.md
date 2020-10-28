# Create and Upload CentOS 7.x for Rendering Studios

These instructions supplement Azure documentation to create and upload an CentOS image and have considerations for the locked down environment of rendering studios.  We highly recommended to start from the CentOS Azure stock images, and use the [image capture process](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image), but these instructions will provide guidance when this is not possible.

Here are the steps to build an image on-premises, upload to Azure, and deploy on Azure:

1. [Build the Custom Image](#build-the-custom-image)
1. [Prepare Image Size and Format for Azure](#prepare-image-size-and-format-for-azure)
1. [Upload Image](#upload-image)
1. [Create and Deploy Image](#create-and-deploy-image)
1. [Next Steps: Image Capture and Scaling](#next-steps-image-capture)
1. [Next Steps: Use VMSS to Scale Deployment](#next-steps-use-vmss-to-scale-deployment)

# Build the Custom Image

Use your current environment to create a CentOS virtual machine image CentOS using the following instructions: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-centos.

Here are the important tips to follow when building the image:

* remove swap partition, as this will eat up your ops on your OS disk.  As an alternative, the Azure Linux Agent (waagent) can configure a swap partition as outlined in the setup instructions

* to enable cloud-init, follow the instructions for [preparing CentOS for cloud-init on Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/cloudinit-prepare-custom-image#preparing-rhel-76--centos-76)

* to run without the WAAgent (and no cloud-init) follow the instructions [Creating generalized images without a provisioning agent](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/no-agent)

* to add a search domain, add a line similar to the following line to `/etc/sysconfig/network-scripts/ifcfg-eth0`
```bash
SEARCH="rendering.com artists.rendering.com"
```

# Prepare Image Size and Format for Azure

Azure requires the following image file requirements:
1. fixed VHD with a ".vhd" extension
1. byte aligned to 1MB chunks + a 512K footer

There are two approaches to converting and resizing the image:
1. **Use qemu-img** - The `qemu-img` command can do the conversion and resizing [described here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic#resizing-vhds).  **Important note** when using `qemu-img` ensure you use the option `force_size`, to get the correct size.

1. **Use Hyper-V tools** - if you are using Hyper-V, use the [Hyper-V manager UI or Powershell tools](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image#convert-the-virtual-disk-to-a-fixed-size-vhd) to convert the disk.  Be sure to choose .vhd and Fixed size.

**Pro-tip:** To make upload less time consuming start with a small image, and it can be resized on the cloud using the [disk_size_gb](https://www.terraform.io/docs/providers/azurerm/r/linux_virtual_machine.html#disk_size_gb) property in terraform.

# Upload Image

Once you have prepared the fixed VHD byte aligned to 1MB chunks + a 512K footer, here are 3 options for upload and image creation:

1. [Internet Restricted: upload via a private endpoint connection enabled storage account](#internet-restricted-upload-via-a-private-endpoint-connection-enabled-storage-account) - for internet restricted environments, this approach enables the upload through a private endpoint ip address on your VNVET.

1. [Upload via a Managed Disk](../securedimage/CreateUploadUbuntu.md#upload-the-custom-image-via-a-managed-disk-by-administrator) - this option does not require a storage account for image creation, but does expose public url to the internet.

1. [Upload via Azure Storage Account](../securedimage/CreateUploadUbuntu.md#upload-the-custom-image-via-a-storage-account-by-administrator) - this approach is useful from low bandwidth, low latency connections, where you are having trouble uploading to the Managed disk URL.  This approach exposes a public URL to the Internet, but simpler than create a private endpoint.

## Internet Restricted: upload via a private endpoint connection enabled storage account

The following instructions create an image using a private storage account endpoint so that traffic does not have to go out on the internet.  The end result of the below is the creation of an image resource, with all other artifacts used for the purpose of creation cleaned up and deleted.

1. browse to http://shell.azure.com, or if you are on your own machine login to az cli
    ```bash
    az login
    ```

1. create the locked down storage account using Azure 
    ```bash
    ##############################
    # SET ENV VARS
    ##############################
    export STG_RESOURCE_GROUP=rendering
    export STG_ACCOUNT_NAME=uniquerenderingstorageaccount
    export CONTAINER_NAME=vhd
    export LOCATION=westus2
    export IMAGES_RESOURCE_GROUP=images
    export VNET_SUBNET_ID=/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/network_rg/providers/Microsoft.Network/virtualNetworks/rendervnet/subnets/render_clients2
    export PRIVATE_ENDPOINT_CONNECTION_NAME=myConnection
    export PRIVATE_ENDPOINT_NAME=myPrivateEndpoint
    export SAS_HOURS=2
    
    ##############################
    # creation
    ##############################
    
    # create the resource group
    az group create --location $LOCATION --resource-group $STG_RESOURCE_GROUP
    
    # create the images resource group
    az group create --location $LOCATION --resource-group $IMAGES_RESOURCE_GROUP
    
    # create the storage account
    az storage account create --name $STG_ACCOUNT_NAME --resource-group $STG_RESOURCE_GROUP --kind StorageV2 --location $LOCATION --sku Standard_LRS | tee sa.txt
    
    export STG_ACCOUNT_ID=$(jq -r '.id' sa.txt)
    rm sa.txt
    
    # create the container on the storage account, before locking down
    az storage container create --name $CONTAINER_NAME --account-name $STG_ACCOUNT_NAME --resource-group $STG_RESOURCE_GROUP
    
    # generate the SAS
    export NOW=$(date -u '+%Y-%m-%dT%H:%MZ')
    export EXPIRE_TIME=$(date -u -d "$SAS_HOURS hours" '+%Y-%m-%dT%H:%MZ')
    export SAS_SUFFIX=$(az storage container generate-sas --account-name $STG_ACCOUNT_NAME --https-only --permissions acdlrw --start $NOW --expiry $EXPIRE_TIME --name $CONTAINER_NAME --output tsv)
    
    # lock down the storage account
    az storage account update --name $STG_ACCOUNT_NAME --resource-group $STG_RESOURCE_GROUP --bypass AzureServices --default-action Deny
    
    # disable network properties on the subnet, so we may place a private endpoint
    az network vnet subnet update --ids $VNET_SUBNET_ID --disable-private-endpoint-network-policies true
    
    # setup the blob endpoint
    az network private-endpoint create \
      --connection-name $PRIVATE_ENDPOINT_CONNECTION_NAME \
      --name $PRIVATE_ENDPOINT_NAME \
      --private-connection-resource-id $STG_ACCOUNT_ID \
      --resource-group $STG_RESOURCE_GROUP \
      --subnet $VNET_SUBNET_ID \
      --group-id blob | tee pe.txt
    
    export PRIVATE_ENDPOINT_ID=$(jq -r '.id' pe.txt)
    export PRIVATE_ENDPOINT_ID=$(jq -r '.id' pe.txt)
    export STORAGE_FQDN=$(jq -r '.customDnsConfigs[0].fqdn' pe.txt)
    export PRIVATE_IP_ADDRESS=$(jq -r '.customDnsConfigs[0].ipAddresses[0]' pe.txt)
    rm pe.txt
    
    echo "# add the following line to /etc/hosts or DNS"
    echo "$PRIVATE_IP_ADDRESS $STORAGE_FQDN"
    
    echo "# sample azcopy command"
    echo "azcopy copy centos.vhd 'https://$STORAGE_FQDN/$CONTAINER_NAME?$SAS_SUFFIX'"
    ```

1. use the hosts line echoed in the previous command to populate the /etc/hosts or DNS with the IP address storage account pair

1. run the `azcopy` command echoed in the previous command to upload the image replacing the source image name `centos.vhd` with your vhd name.

1. create the image, updating the variables below
    ```bash
    export SOURCE_URL="https://$STORAGE_FQDN/$CONTAINER_NAME/centos.vhd"
    export IMAGE_NAME=centos
    az image create --location $LOCATION --resource-group $IMAGES_RESOURCE_GROUP --name $IMAGE_NAME --os-type Linux --source $SOURCE_URL
    echo "# use the following image id in your terraform"
    echo "    image_resource_group = \"$IMAGES_RESOURCE_GROUP\"
        image_name = \"$IMAGE_NAME\""
    ```

1. cleanup the resource group, storage account, private endpoint, and restore the subnet.  This will not delete the newly created image.
    ```bash
    # delete the private endpoint
    az network private-endpoint delete --ids $PRIVATE_ENDPOINT_ID
    
    # enable network properties on the subnet, since we are complete
    az network vnet subnet update --ids $VNET_SUBNET_ID --disable-private-endpoint-network-policies false
    
    # delete the storage account
    az storage account delete --yes --name $STG_ACCOUNT_NAME --resource-group $STG_RESOURCE_GROUP
    
    # delete the resource group
    az group delete --yes --resource-group $STG_RESOURCE_GROUP
    ```

# Create and Deploy Image

These instructions create a virtual machine using the image created above.  The example, exercises cloud-init and custom-script extension. 

1. browse to https://shell.azure.com

1. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You can verify you are running in the context of your subscription by running ```az account show```

1. get the terraform examples
    ```bash
    mkdir tf
    cd tf
    git init
    git remote add origin -f https://github.com/Azure/Avere.git
    git config core.sparsecheckout true
    echo "src/terraform/*" >> .git/info/sparse-checkout
    git pull origin main
    ```

1. `cd ~/tf/src/terraform/examples/centos`

1. `code main.tf` to edit the local variables section at the top of the file, populate the image resource group and image name created in the previous section.

1. execute `terraform init` in the directory of `main.tf`.

1. execute `terraform apply -auto-approve` to build the virtual machine

You can now modify the image and capture as outlined in the next section.

Once you have tested and or captured your image, you can delete it by running `terraform destroy -auto-approve` or you can capture a new image as decribed in the Next Steps.  Once you are happy with your image, you can scale it using the associated VMSS example.

# Next Steps: Image Capture

Now that you have the image in cloud you may want to refine it, and that is done in the capture phase described in the following document: https://docs.microsoft.com/en-us/azure/virtual-machines/linux/capture-image.  Step 2 of the document provides the automation commands, but these commands of deallocate, generalize, and image create can all be done by clicking the "capture" button on the VM page in the portal.

If you use the "capture" button, and choose delete VM, you will still need to remove the associated NIC and disk.

# Next Steps: Use VMSS to Scale Deployment

Once the image is created, you can scale by using vmss.  The following template uses the best practices outlined in [Best Practices for using Azure Virtual Machine Scale Sets (VMSS) or Azure Cycle Cloud for Rendering](../vmss-rendering)

1. `cd ~/tf/src/terraform/examples/centos/vmss`

1. `code main.tf` to edit the local variables section at the top of the file, populate the image resource group and image name created in the previous section.

1. execute `terraform init` in the directory of `main.tf`.

1. execute `terraform apply -auto-approve` to build the Virtual Machine Scale Set

Once you have tested and scaled the image, you can destroy by running `terraform destroy -auto-approve`.