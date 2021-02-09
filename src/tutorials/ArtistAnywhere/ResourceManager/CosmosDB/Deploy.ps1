param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"        # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $cosmosAccount = @{                 # https://docs.microsoft.com/azure/cosmos-db/introduction
        "name" = ""
        "offerType" = "Standard"
        "uiType" = "Non-Production"
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.cosmosAccount.value = $cosmosAccount
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
