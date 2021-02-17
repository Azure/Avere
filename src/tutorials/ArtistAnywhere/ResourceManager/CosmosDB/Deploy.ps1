param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $cosmosAccount = @{             # https://docs.microsoft.com/azure/cosmos-db/introduction
        "name" = ""
        "type" = "GlobalDocumentDB"
        "offerType" = "Standard"
        "userInterfaceType" = "Non-Production"
        "defaultExperience" = "Core (SQL)"
        "capabilities" = @(
            @{
                "name" = "EnableServerless"
            }
        )
    },
    $sqlDatabase = @{
        "name" = ""
        "containers" = @(
            @{
                "name" = ""
                "partitionKey" = @{
                    "type" = "Hash"
                    "path" = "/id"
                }
            }
        )
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.cosmosAccount.value = $cosmosAccount
$templateConfig.parameters.sqlDatabase.value = $sqlDatabase
$templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
