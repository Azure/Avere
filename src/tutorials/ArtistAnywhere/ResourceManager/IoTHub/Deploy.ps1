param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $iotHub = @{                # https://docs.microsoft.com/azure/iot-hub/about-iot-hub
        "name" = ""
        "tier" = @{
            "name" = "S1"
            "units" = 1
        }
        "eventHub" = @{
            "partitionCount" = 4
            "dataRetentionDays" = 1
        }
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.iotHub.value = $iotHub
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
