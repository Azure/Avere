param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $quantumWorkspace = @{      # https://docs.microsoft.com/azure/quantum/overview-azure-quantum
        "name" = ""
        "providers" = @(
            @{
                "providerId" = "Microsoft"
                "providerSku" = "DZH3178M639F"
            }
        )
    },
    $storageAccount = @{        # https://docs.microsoft.com/azure/storage/common/storage-account-overview
        "name" = ""
        "resourceGroupName" = ""
    }
)

# "Batch" {
#     $principalType = "ServicePrincipal"

#     $principalId = "f520d84c-3fd3-4cc8-88d4-2ed25b00d27a" # Microsoft Azure Batch
#     $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"      # Contributor

#     $subscriptionId = az account show --query "id" --output "tsv"
#     $subscriptionId = "/subscriptions/$subscriptionId"

#     Set-RoleAssignment $roleId $principalId $principalType $subscriptionId $false

#     az keyvault update --resource-group $keyVault.resourceGroupName --name $keyVault.name --enable-rbac-authorization $false --output none --only-show-errors
#     az keyvault set-policy --resource-group $keyVault.resourceGroupName --name $keyVault.name --object-id $principalId --secret-permissions Get List Set Delete --output none
#     az keyvault update --resource-group $keyVault.resourceGroupName --name $keyVault.name --enable-rbac-authorization $true --output none --only-show-errors
# }

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.quantumWorkspace.value = $quantumWorkspace
$templateConfig.parameters.storageAccount.value = $storageAccount
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
