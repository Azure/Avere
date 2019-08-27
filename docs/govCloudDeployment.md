Prereqs:

https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#configure-subscription-owner-permissions

Deploy controller:


az login:

https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli
az cloud set --name AzureUSGovernment
az login


Accept license terms:
https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-prereqs#accept-software-terms

az account set --subscription abc123de-f456-abc7-89de-f01234567890
az vm image accept-terms --urn microsoft-avere:vfxt:avere-vfxt-controller:latest

Create role:

az role definition create --role-definition avere-cluster.json

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

Edit deployment script:
vi /create-cloudbacked-cluster


List locations:
az account list-locations

