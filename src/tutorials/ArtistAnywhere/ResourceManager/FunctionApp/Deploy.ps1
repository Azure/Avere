param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $functionApp = @{
        "name" = ""
        "runtime" = "Python|3.8"    # https://docs.microsoft.com/azure/azure-functions/functions-versions
        "linux" = $true
    },
    $hostingPlan = @{
        "name" = ""
        "tier" = "ElasticPremium"   # https://docs.microsoft.com/azure/azure-functions/functions-premium-plan
        "size" = "EP1"
    },
    $storageAccount = @{            # https://docs.microsoft.com/azure/storage/common/storage-introduction
        "name" = ""
        "resourceGroupName" = ""
    },
    $insightAccount = @{            # https://docs.microsoft.com/azure/azure-monitor/overview
        "name" = ""
        "type" = "PerGB2018"
        "dataRetentionDays" = 90
        "networkAccess" = @{
            "publicIngest" = $false
            "publicQuery" = $false
        }
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

if ($insightAccount.name -ne "") {
    $templateFile = "$PSScriptRoot/../MonitorInsight/Template.json"
    $templateParameters = "$PSScriptRoot/../MonitorInsight/Template.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.insightAccount.value = $insightAccount
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $appInsights = $groupDeployment.properties.outputs.appInsights.value
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.functionApp.value = $functionApp
$templateConfig.parameters.hostingPlan.value = $hostingPlan
$templateConfig.parameters.storageAccount.value = $storageAccount
$templateConfig.parameters.appInsights.value = $appInsights
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
