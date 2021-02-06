param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },

    $imageGallery = @{              # https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries
        "name" = ""
        "imageDefinitions" = @(
            @{
                "name" = "ServerLinux"
                "type" = "Linux"
                "generation" = "v1"
                "state" = "Generalized"
                "publisher" = "OpenLogic"
                "offer" = "CentOS"
                "sku" = "8_3"
            },
            @{
                "name" = "ServerWindows"
                "type" = "Windows"
                "generation" = "v1"
                "state" = "Generalized"
                "publisher" = "MicrosoftWindowsServer"
                "offer" = "WindowsServer"
                "sku" = "2019-Datacenter"
            },
            @{
                "name" = "WorkstationLinux"
                "type" = "Linux"
                "generation" = "v1"
                "state" = "Generalized"
                "publisher" = "OpenLogic"
                "offer" = "CentOS"
                "sku" = "7_9"
            },
            @{
                "name" = "WorkstationWindows"
                "type" = "Windows"
                "generation" = "v1"
                "state" = "Generalized"
                "publisher" = "MicrosoftWindowsDesktop"
                "offer" = "Windows-10"
                "sku" = "20H2-Pro"
            }
        )
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.imageGallery.value = $imageGallery
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
