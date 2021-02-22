param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $quantumWorkspace = @{          # https://docs.microsoft.com/azure/quantum/overview-azure-quantum
        "name" = ""
        "providers" = @(
            @{
                "providerId" = "Microsoft"
                "providerSku" = "DZH3178M639F"
            }
        )
    },
    $storageAccount = @{            # https://docs.microsoft.com/azure/storage/common/storage-account-overview
        "name" = ""
        "resourceGroupName" = $resourceGroup.name
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.quantumWorkspace.value = $quantumWorkspace
$templateConfig.parameters.storageAccount.value = $storageAccount
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
