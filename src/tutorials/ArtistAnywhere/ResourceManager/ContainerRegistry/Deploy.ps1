param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $containerRegistry = @{     # https://docs.microsoft.com/azure/container-registry/container-registry-intro
        "name" = ""
        "tier" = "Premium"
        "enableAdminUser" = $true
        "enableDataEndpoint" = $true
        "enablePublicNetwork" = $false
        "enablePrivateEndpoint" = $true
        "managedIdentity" = @{  # https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
            "name" = $containerRegistry.name
            "type" = "UserAssigned" # None, SystemAssigned or UserAssigned
        }
    },
    $virtualNetwork = @{        # https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = $resourceGroup.name
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

if ($containerRegistry.managedIdentity.type -eq "UserAssigned") {
    az identity create --resource-group $resourceGroup.name --name $containerRegistry.managedIdentity.name
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.containerRegistry.value = $containerRegistry
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
