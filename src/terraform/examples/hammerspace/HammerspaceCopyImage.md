# Copy the Hammerspace Image To your Subscription

After you have received the SAS URL from the [Hammerspace representative](https://hammerspace.com/contact/), use the following instructions to copy the image to each target region where you want to deploy a Hammerspace filer.

1. open https://shell.azure.com

1. copy the following bash script to a file in cloud shell, update the "exports" and execute to perform the copy

```bash
#!/bin/bash

#########################
# Configurable Variables
#########################
export LOCATION=eastus
export SUBSCRIPTIONID=
export CUSTOMIMAGE_RESOURCEGROUP=
export HAMMERSPACE_NAME=Hammerspace.vhd

##############################
# Get the SAS URLs from HAMMERSPACE
##############################
export HAMMERSPACE_URL=''

########################################
# create the group if not already exists
########################################
az account set --subscription $SUBSCRIPTIONID
az group create --location $LOCATION --name $CUSTOMIMAGE_RESOURCEGROUP

##############################
# create the HAMMERSPACE image
##############################
export HAMMERSPACE_SIZE=$(curl -s --head $HAMMERSPACE_URL | grep Content-Length | cut -d " " -f 2)
az disk create -n $HAMMERSPACE_NAME --location $LOCATION --resource-group $CUSTOMIMAGE_RESOURCEGROUP --for-upload --upload-size-bytes $HAMMERSPACE_SIZE --sku standard_lrs
az disk grant-access -n $HAMMERSPACE_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP --access-level Write --duration-in-seconds 3600
export HAMMERSPACE_SAS=$(az disk grant-access -n $HAMMERSPACE_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP --access-level Write --duration-in-seconds 3600 --query "accessSas" -otsv)
azcopy copy $HAMMERSPACE_URL $HAMMERSPACE_SAS
az disk revoke-access -n $HAMMERSPACE_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP
az image create --location $LOCATION --resource-group $CUSTOMIMAGE_RESOURCEGROUP --name $HAMMERSPACE_NAME --os-type Linux --source $(az disk list -g $CUSTOMIMAGE_RESOURCEGROUP --query "[?name=='$HAMMERSPACE_NAME'].id | [0]" -otsv)
az disk delete -n $HAMMERSPACE_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP -y

###############################
# Dump the custom image ids
###############################
az image list -g $CUSTOMIMAGE_RESOURCEGROUP --query "[].id"

```