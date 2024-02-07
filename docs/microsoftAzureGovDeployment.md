# Standing up vFXT in Azure Government Cloud

## Prereqs:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#configure-subscription-owner-permissions

## Deploy controller:

https://portal.azure.us/#create/microsoft-avere.vfxtavere-vfxt-controller

## Login to controller and sudo to root
```
sudo -s
```

## Login to Azure CLI:

https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
```
az cloud set --name AzureUSGovernment
az login
```

## Accept license terms:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms

```
az account set --subscription abc123de-f456-abc7-89de-f01234567890
az vm image terms accept --urn microsoft-avere:vfxt:avere-vfxt-controller:latest
```

## Create role:
```
az role definition create --role-definition avere-cluster.json
```
json file looks like this:
```
{
    "AssignableScopes": [
        "/subscriptions/f75a88ac-70d5-405e-a2fd-95b308e8042a"
    ],
    "Name": "avere-cluster",
    "IsCustom": "true",
    "Description": "Avere cluster runtime role",
    "NotActions": [],
    "Actions": [
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Network/networkInterfaces/read",
        "Microsoft.Network/networkInterfaces/write",
    "Microsoft.Network/virtualNetworks/read",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/networkSecurityGroups/join/action",
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
```

## Deploy vFXT

Edit deployment script:
```
vi /create-minimal-cluster
```

Change these values:
```
+ RESOURCE_GROUP=avere-rg
+ LOCATION=usgovvirginia
+ NETWORK=avere-rg-vnet
+ SUBNET=default
+ AVERE_CLUSTER_ROLE=avere-cluster
+ CLUSTER_NAME=avere-cluster-fairfax
+ ADMIN_PASSWORD=<CHOOSE PASSWORD FOR CLUSTER>
+ INSTANCE_TYPE=Standard_E32s_v3
+ CACHE_SIZE=4096
```
## Configure vFXT
###### Create cloud filer:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-add-storage#create-a-core-filer
https://azure.github.io/Avere/legacy/ops_guide/4_7/html/new_core_filer_cloud.html

```
bucketname=storageaccount/containername
(ex: avereblobstorage/avereblob)
```

**Caveat - different storage endpoint is needed for Microsoft Azure Government**

Need to SSH to avere cluster node and manually change the 'mass' name. 
```
dbutil.py set mass2 serverName avereblobstorage.blob.core.usgovcloudapi.net -x
```

Was set to:
```
serverName: URI_TO_AZURE_STORAGE_ACCOUNT
```

###### Configure junction:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-add-storage#create-a-junction

###### Mount junction:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-mount-clients

###### Moving data onto vFXT:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-data-ingest



## Helpful az commands:

List accounts:
```
az account show
```
List roles:
```
az role definition list
```
List locations:
```
az account list-locations
```
