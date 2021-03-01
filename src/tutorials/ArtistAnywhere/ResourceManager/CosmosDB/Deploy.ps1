param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $cosmosAccount = @{         # https://docs.microsoft.com/azure/cosmos-db/introduction
        "name" = ""
        "type" = "GlobalDocumentDB"
        "offerType" = "Standard"
        "defaultExperience" = "Core (SQL)"
        "userInterfaceType" = "Non-Production"
        "capabilities" = @(     # https://docs.microsoft.com/azure/cosmos-db/serverless
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
                "partitionKey" = @{ # https://docs.microsoft.com/azure/cosmos-db/partitioning-overview
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
