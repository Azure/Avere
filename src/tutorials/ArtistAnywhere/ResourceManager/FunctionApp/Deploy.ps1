param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS"     # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $functionApp = @{
        "name" = ""
        "runtime" = ""              # https://docs.microsoft.com/azure/azure-functions/functions-versions
    },
    $hostingPlan = @{
        "name" = ""
        "tier" = "ElasticPremium"   # https://docs.microsoft.com/azure/azure-functions/functions-premium-plan
        "size" = "EP1"
    },
    $storageAccount = @{            # https://docs.microsoft.com/azure/storage/common/storage-introduction
        "name" = ""
        "resourceGroupName" = ""
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.functionApp.value = $functionApp
$templateConfig.parameters.hostingPlan.value = $hostingPlan
$templateConfig.parameters.storageAccount.value = $storageAccount
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
