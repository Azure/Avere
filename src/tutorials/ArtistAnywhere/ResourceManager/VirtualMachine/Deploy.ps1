param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $virtualMachine = @{        # https://docs.microsoft.com/azure/virtual-machines/
        "name" = ""
    },
    $virtualNetwork = @{        # https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = ""
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.virtualMachine.value = $virtualMachine
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
