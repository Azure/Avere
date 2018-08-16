# Avere vFXT deployment

This 30 minute deployment will create from scratch a storage account backed Avere vFXT cluster.  Additionally this creates the necessary infrastructure including a VNET, the backing storage account, and the vFXT Controller.  By the end of the demo you will have the resources shown in the following diagram:

<img src="images/vfxt_deployment.png">

As you go through this deployment, you will need to save the following important outputs for later use.  We recommend you fill in the following tracking table as you proceed through the deployment, and save it in a safe place.

|Key|Value|
|---|---|
|Location|`region value from output after deploying controller, eg. "eastus2"`|
|Controller SSH String|`ssh string output after controller deployment`|
|Subnet ID|`value from output after deploying controller`|
|Avere Management IP|`IP Address output during vFXT creation`|
|Avere vFXT NFS IP Range CSV|`A CSV list of IP Address output by the vFXT`|
|Encryption Key|`from Avere vFXT Management EP - covered in Using the vFXT`|

# Deploy the Avere Controller and VNET

The Avere vFXT controller helps you install and manage an Avere vFXT cluster.

You can deploy the Avere vFXT through the portal, or through the cloud shell.  Here are two important nodes when deploying:

  1. **SSH Key** if you need to create an ssh key, follow these [generation instructions](https://github.com/Azure/acs-engine/blob/master/docs/ssh.md#ssh-key-generation)
  1. **No-Password Protected SSH Key** make sure you don't create a password protected SSH key.
  1. **Unique Name** the *uniquename* below is used for creation of your storage account and DNS name.  You may encounter an error *StorageAccountAlreadyTaken*.  If this happens, please choose another unique name.

## Portal Install

To install from the portal, launch the deployment by clicking the "Deploy to Azure" button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Favereimageswestus.blob.core.windows.net%2Fgithubcontent%2Fsrc%2Fvfxt%2Fazuredeploy.json" target="_blank">
<img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>

Save the output values of the deployment for the vFXT deployment, and capture `location`, `sshString`, and `subnetref` to your tracking table described at the beginning of this document.

## Cloud Shell Install

1. To deploy the controller, first open a cloud shell from the [portal](http://portal.azure.com) or [cloud shell](https://shell.azure.com/).

2. If this is your first time deploying the vFXT, you will need to accept the legal terms.  Change the cloud shell to powershell mode and accept the terms for your subscription by running the following commands updating the **SUBSCRIPTION_ID**:

```powershell
PS C:\> Select-AzureRmSubscription -SubscriptionID #SUBSCRIPTION_ID
PS C:\> Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-controller" | Set-AzureRmMarketplaceTerms -Accept
PS C:\> Get-AzureRmMarketplaceTerms -Publisher "microsoft-avere" -Product "vfxt" -Name "avere-vfxt-node" | Set-AzureRmMarketplaceTerms -Accept
```

3. Change the cloud shell back to linux shell, and run the following commands in cloud shell to deploy, updating the commented variables:

```bash
# set the subscription, resource group, and location
export DstSub=#"SUBSCRIPTION_ID"
export DstResourceGroupName=#"exampleresourcegroup"
export DstLocation=#"eastus2"

# get the Avere vFXT controller template and edit parameters
curl -o azuredeploy.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vfxt/azuredeploy.json
curl -o azuredeploy.parameters.json https://avereimageswestus.blob.core.windows.net/githubcontent/src/vfxt/azuredeploy.parameters.json
vi azuredeploy.parameters.json

# deploy the template
az account set --subscription $DstSub
az group create --name $DstResourceGroupName --location $DstLocation
az group deployment create --resource-group $DstResourceGroupName --template-file azuredeploy.json --parameters @azuredeploy.parameters.json
```

4. Scroll-up in the deployment output to a section labelled `"outputs"` and save the values for the vFXT deployment, and capture `location`, `sshString`, and `subnetref` to your tracking table described at the beginning of this document.

# Deploy the Avere vFXT cluster

1. SSH to your controller using the `sshString` output from the previous deployment.

2. Once connected to the controller run the following commands:

```bash
sudo -s
cd /
az login
az account set --subscription "SUBSCRIPTION_ID"
```
3. Verify the AD role exists for your subscription, otherwise create it, by copy /pasting the following script into the shell.  The role enables the vFXT to talk to ARM.

```bash
# The preconfigured Azure AD role for use by the vFXT cluster nodes.  Refer to
# the vFXT documentation.
AVERE_CLUSTER_ROLE=avere-cluster-role

#
# Add the role if it does not already exist
# 
az role definition list | grep $AVERE_CLUSTER_ROLE > /dev/null
AVERE_ROLE_EXISTS=$?
set -e
if [ $AVERE_ROLE_EXISTS -ne 0 ]
then
            # create the profile
                echo "create profile"
                    cat > avere-cluster-role.json <<EOL
{ 
    "AssignableScopes": [
        "/subscriptions/${SUBSCRIPTION_ID}",
    ],
    "Name": "${AVERE_CLUSTER_ROLE}",
    "IsCustom": "true",
    "Description": "Avere cluster runtime role",
    "NotActions": [],
    "Actions": [
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Network/networkInterfaces/read",
        "Microsoft.Network/networkInterfaces/write",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
         "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
        "Microsoft.Storage/storageAccounts/blobServices/containers/read",
        "Microsoft.Storage/storageAccounts/blobServices/containers/write"
    ],
    "DataActions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write"
    ]
}
EOL
    az role definition create --role-definition avere-cluster-role.json
fi
```
4. Edit the file `/create-cloudbacked-cluster`, and update the commented variables below: 

```bash
# Resource groups
# At a minimum specify the resource group.  If the network resources live in a
# different group, specify the network resource group.  Likewise for the storage
# account resource group.
RESOURCE_GROUP=#FROM CONTROLLER DEPLOYMENT OUTPUT
#NETWORK_RESOURCE_GROUP=
#STORAGE_RESOURCE_GROUP=

# eastus, etc.  To list:
# az account list-locations --query '[].name' --output tsv
LOCATION=#FROM CONTROLLER DEPLOYMENT OUTPUT

# Your VNET and Subnet names. NOTE: you must have a route table that is associated
# with your subnet.
NETWORK=#FROM CONTROLLER DEPLOYMENT OUTPUT
SUBNET=#FROM CONTROLLER DEPLOYMENT OUTPUT

# The preconfigured Azure AD role for use by the vFXT cluster nodes.  Refer to
# the vFXT documentation.
AVERE_CLUSTER_ROLE=avere-cluster-role

# For cloud (blob) backed storage, provide the storage account name for the data
# to live within.
STORAGE_ACCOUNT=#FROM CONTROLLER DEPLOYMENT OUTPUT

# The cluster name is the prefix for the cluster node VMs.
CLUSTER_NAME=avere-cluster
# Administrative password for the cluster
ADMIN_PASSWORD=#UPDATE PASSWORD
```

5. Execute the script by typing `/create-cloudbacked-cluster`

6. The averefxt cluster will be created in about 15 minutes.

Now that you have completed the installation, visit [Using the vFXT](using_the_vfxt.md) to learn how to use the Avere vFXT cluster.