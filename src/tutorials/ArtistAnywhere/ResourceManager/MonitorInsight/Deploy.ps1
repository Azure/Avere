param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $insightAccount = @{         # https://docs.microsoft.com/azure/azure-monitor/overview
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

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.insightAccount.value = $insightAccount
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
