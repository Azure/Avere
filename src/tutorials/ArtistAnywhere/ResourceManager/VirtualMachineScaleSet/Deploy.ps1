param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS"         # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $virtualMachineScaleSet = @{        # https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview
        "name" = ""
        "image" = @{
            "name" = ""
            "resourceGroupName" = $resourceGroup.name
            # OR
            "galleryName" = ""
            "definitionName" = ""
            "versionId" = "1.0.0"
            # OR
            "publisher" = ""
            "offer" = ""
            "sku" = ""
            "version" = "latest"
        }
        "machine" = @{
            "size" = ""
            "count" = 0
            "priority" = "Spot"
            "evictionPolicy" = "Delete"
            "maxPrice" = ""
        }
        "osDisk" = @{
            "storageAccountType" = "Standard_LRS"
            "enableEphemeral" = $false
        }
        "login" = @{
            "adminUsername" = ""
            "adminPassword" = ""
            "sshPublicKeyData" = ""
        }
        "managedIdentity" = @{          # https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
            "name" = $virtualMachineScaleSet.name
            "type" = "UserAssigned"     # None, SystemAssigned or UserAssigned
        }
        "scriptExtension" = @{          # https://docs.microsoft.com/azure/virtual-machines/extensions/custom-script-linux
            "enable" = $false           # https://docs.microsoft.com/azure/virtual-machines/extensions/custom-script-windows
            "command" = ""
            "parameters" = ""
            "domainName" = ""
        }
        "faultDomainCount" = 1
        "upgradePolicy" = "Manual"
        "singlePlacementGroup" = $false
        "overprovision" = $false
    },
    $virtualNetwork = @{                # https://docs.microsoft.com/azure/virtual-network/virtual-networks-overview
        "name" = ""
        "subnetName" = ""
        "resourceGroupName" = $resourceGroup.name
    }
)

function Get-ScriptCommand ($scriptFile, $scriptParameters) {
    $scriptText = Get-Content $scriptFile -Raw
    if ($scriptFile.EndsWith(".ps1")) {
        $scriptText = "& {" + $scriptText + "} " + $scriptParameters
    } else {
        $scriptCommand = $scriptText
    }
    $scriptCommand = [System.Text.Encoding]::Unicode.GetBytes($scriptText)
    return [Convert]::ToBase64String($scriptCommand)
}

az group create --name $resourceGroup.name --location $resourceGroup.regionName

if ($virtualMachineScaleSet.managedIdentity.type -eq "UserAssigned") {
    az identity create --resource-group $resourceGroup.name --name $virtualMachineScaleSet.managedIdentity.name
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

if ($virtualMachineScaleSet.image.name -ne "") {
    $image = (az image show --resource-group $virtualMachineScaleSet.image.resourceGroupName --name $virtualMachineScaleSet.image.name) | ConvertFrom-Json
    $osType = $image.storageProfile.osDisk.osType
} elseif ($virtualMachineScaleSet.image.galleryName -ne "") {
    $imageDefinition = (az sig image-definition show --resource-group $virtualMachineScaleSet.image.resourceGroupName --gallery-name $virtualMachineScaleSet.image.galleryName --gallery-image-definition $virtualMachineScaleSet.image.definitionName) | ConvertFrom-Json
    $osType = $imageDefinition.osType
} else {
    $imageId = $virtualMachineScaleSet.image.publisher + ":" + $virtualMachineScaleSet.image.offer + ":" + $virtualMachineScaleSet.image.sku + ":" + $virtualMachineScaleSet.image.version
    $image = (az vm image show --urn $imageId) | ConvertFrom-Json
    $osType = $image.osDiskImage.operatingSystem
}

if ($virtualMachineScaleSet.scriptExtension.enable) {
    if ($osType -eq "Windows") {
        $scriptParameters = "-domainName " + $virtualMachineScaleSet.scriptExtension.domainName
        $scriptCommand = Get-ScriptCommand "$PSScriptRoot/Customize.ps1" $scriptParameters
    } else {
        $scriptParameters = "domainName=" + $virtualMachineScaleSet.scriptExtension.domainName
        $scriptCommand = Get-ScriptCommand "$PSScriptRoot/Customize.sh" $scriptParameters
    }
    $virtualMachineScaleSet.scriptExtension.command = $scriptCommand
    $virtualMachineScaleSet.scriptExtension.parameters = $scriptParameters
}

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.virtualMachineScaleSet.value = $virtualMachineScaleSet
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
