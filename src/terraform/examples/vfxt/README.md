# Avere vFXT for Azure

The examples in this folder build various configurations of the Avere vFXT with IaaS based filers:

1. [Avere vFXT for Azure](no-filers/)
2. [Avere vFXT mounting Azure Blob Storage cloud core filer example](azureblobfiler/)
3. [Avere vFXT for Azure mounting 1 IaaS NAS filer](1-filer/)
4. [Avere vFXT for Azure mounting 3 IaaS NAS filers](3-filers/)
5. [Avere vFXT for Azure mounting an Azure Netapp Volume](netapp/)
6. [Avere vFXT optimized for Houdini](HoudiniOptimized/)
7. [Avere vFXT and VDBench example](vdbench/)
8. [Avere vFXT and VMSS example](vmss/)
9. [Avere vFXT and Cloud Workstations](cloudworkstation/)
10. [Avere vFXT only](vfxt-only/) - this example is useful for when the cloud environment is already configured.
11. [Avere vFXT in a Proxy Environment](examples/vfxt/proxy) - this example shows how to deploy the Avere in a locked down internet environment, with a proxy.


# Create vFXT Controller from Custom Images

Occasionally you may need to deploy the Avere vFXT and Controller from custom images.  Below are the instructions:

1. Browse to https://shell.azure.com

2. create a build script by executing `touch buildimages.sh`

3. edit the file `code buildimages.sh`, add the following content, and update the configurable variables with the SAS URLs provided from Avere.

```bash
#########################
# Configurable Variables
#########################
export LOCATION=eastus
export SUBSCRIPTIONID=
export CUSTOMIMAGE_RESOURCEGROUP=
export CONTROLLER_NAME=
export VFXT_NAME=

##############################
# Get the SAS URLs from Avere
##############################
export CONTROLLER_URL=''
export VFXT_URL=''

########################################
# create the group if not already exists
########################################
az account set --subscription $SUBSCRIPTIONID
az group create --location $LOCATION --name $CUSTOMIMAGE_RESOURCEGROUP

##############################
# create the controller image
##############################
export CONTROLLER_SIZE=$(curl -s --head $CONTROLLER_URL | grep Content-Length | cut -d " " -f 2)
az disk create -n $CONTROLLER_NAME --location $LOCATION --resource-group $CUSTOMIMAGE_RESOURCEGROUP --for-upload --upload-size-bytes $CONTROLLER_SIZE --sku standard_lrs
az disk grant-access -n $CONTROLLER_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP --access-level Write --duration-in-seconds 3600
export CONTROLLER_SAS=$(az disk grant-access -n $CONTROLLER_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP --access-level Write --duration-in-seconds 3600 --query "accessSas" -otsv)
azcopy copy $CONTROLLER_URL $CONTROLLER_SAS
az disk revoke-access -n $CONTROLLER_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP
az image create --location $LOCATION --resource-group $CUSTOMIMAGE_RESOURCEGROUP --name $CONTROLLER_NAME --os-type Linux --source $(az disk list -g $CUSTOMIMAGE_RESOURCEGROUP --query "[?name=='$CONTROLLER_NAME'].id | [0]" -otsv)
az disk delete -n $CONTROLLER_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP -y

##############################
# create the vfxt image
##############################
export VFXT_SIZE=$(curl -s --head $VFXT_URL | grep Content-Length | cut -d " " -f 2)
az disk create -n $VFXT_NAME --location $LOCATION --resource-group $CUSTOMIMAGE_RESOURCEGROUP --for-upload --upload-size-bytes $VFXT_SIZE --sku standard_lrs
az disk grant-access -n $VFXT_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP --access-level Write --duration-in-seconds 3600
export VFXT_SAS=$(az disk grant-access -n $VFXT_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP --access-level Write --duration-in-seconds 3600 --query "accessSas" -otsv)
azcopy copy $VFXT_URL $VFXT_SAS
az disk revoke-access -n $VFXT_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP
az image create --location $LOCATION --resource-group $CUSTOMIMAGE_RESOURCEGROUP --name $VFXT_NAME --os-type Linux --source $(az disk list -g $CUSTOMIMAGE_RESOURCEGROUP --query "[?name=='$VFXT_NAME'].id | [0]" -otsv)
az disk delete -n $VFXT_NAME --resource-group $CUSTOMIMAGE_RESOURCEGROUP -y

###############################
# Dump the custom image ids
###############################
az image list -g $CUSTOMIMAGE_RESOURCEGROUP --query "[].id"
```

4. execute the script `./buildimages.sh`

5. copy the two image IDs output

Now you can use any of the vFXT examples and pass in for the controller and vfxt image ids.