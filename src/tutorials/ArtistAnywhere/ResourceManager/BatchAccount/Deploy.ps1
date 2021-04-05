param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS"     # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $batchAccount = @{              # https://docs.microsoft.com/azure/batch/batch-technical-overview
        "name" = ""
        "enableUserSubscription" = $true
        "enablePublicNetwork" = $false
        "managedIdentity" = @{
            "name" = $batchAccount.name
            "type" = "UserAssigned" # None, SystemAssigned or UserAssigned
        }
    },
    $storageAccount = @{            # https://docs.microsoft.com/azure/storage/common/storage-account-overview
        "name" = $batchAccount.name
        "type" = "StorageV2"
        "replication" = "Standard_LRS"
    },
    $keyVault = @{                  # https://docs.microsoft.com/azure/key-vault/general/overview
        "name" = $batchAccount.name
        "tier" = "Standard"
        "enableDeployment" = $true
        "enableDiskEncryption" = $true
        "enableTemplateDeployment" = $true
        "enableRbacAuthorization" = $false
        "enablePurgeProtection" = $false
        "softDeleteRetentionDays" = 90
    },
    $virtualNetwork = @{            # https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = $resourceGroup.name
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

if ($batchAccount.managedIdentity.type -eq "UserAssigned") {
    az identity create --resource-group $resourceGroup.name --name $batchAccount.managedIdentity.name
}

if ($batchAccount.userSubscriptionMode) {
    $principalType = "ServicePrincipal"
    $principalId = "f520d84c-3fd3-4cc8-88d4-2ed25b00d27a" # Microsoft Azure Batch
    $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"      # Contributor
    $scopeId = "/subscriptions/" + (az account show --query "id" --output "tsv")
    az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --scope $scopeId
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.batchAccount.value = $batchAccount
$templateConfig.parameters.storageAccount.value = $storageAccount
$templateConfig.parameters.keyVault.value = $keyVault
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
