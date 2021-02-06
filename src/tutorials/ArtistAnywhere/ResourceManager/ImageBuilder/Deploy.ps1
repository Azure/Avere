param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $imageTemplate = @{             # https://docs.microsoft.com/azure/virtual-machines/image-builder-overview
        "name" = ""
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.imageTemplate.value = $imageTemplate
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
