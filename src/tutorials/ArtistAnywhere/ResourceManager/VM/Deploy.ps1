param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2" # https://azure.microsoft.com/global-infrastructure/geographies/
    },

    $imageGallery = @{
        "name" = ""
        "resourceGroupName" = ""
        "imageDefinitionName" = ""
        "imageVersionId" = "1.0.0"
    },
    # OR
    $managedImage = @{
        "name" = ""
        "resourceGroupName" = ""
    },

    $virtualMachine = @{
        "scaleSetName" = "renderFarm"
        "namePrefix" = "render"
        "instanceCount" = 0
        "instanceSize" = "Standard_HB120rs_v2"
        "osEphemeralDisk" = $false
        "evictionPolicy" = "Delete"
        "upgradePolicy" = "Manual"
        "priority" = "Spot"
        "maxPrice" = ""
        "username" = "az"
        "password" = "P@ssword1234"
    },

    $virtualNetwork = @{
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = ""
    },

    $joinDomain = @{
        "name" = "media.studio"
        "ouPath" = "OU=render,DC=media,DC=studio"
        "options" = 3 # https://docs.microsoft.com/windows/win32/cimwin32prov/joindomainorworkgroup-method-in-class-win32-computersystem
        "username" = ""
        "password" = ""
    }
)

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.managedImage.value = $managedImage
$templateConfig.parameters.imageGallery.value = $imageGallery
$templateConfig.parameters.virtualMachine.value = $virtualMachine
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig.parameters.joinDomain.value = $joinDomain
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
