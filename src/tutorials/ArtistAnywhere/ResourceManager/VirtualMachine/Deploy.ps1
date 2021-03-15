param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS"         # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $virtualMachine = @{                # https://docs.microsoft.com/azure/virtual-machines/
        "name" = ""
        "size" = "Standard_NV12s_v3"    # https://docs.microsoft.com/azure/virtual-machines/sizes
        "image" = @{
            "name" = ""
            "resourceGroupName" = $resourceGroup.name
            # OR
            "galleryName" = ""          # https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries
            "definitionName" = ""
            "versionId" = "1.0.0"
            # OR
            "publisher" = ""
            "offer" = ""
            "sku" = ""
            "version" = "latest"
        }
        "osDisk" = @{
            "caching" = "ReadOnly"
            "storageAccountType" = "Premium_LRS"
        }
        "login" = @{
            "adminUsername" = ""
            "adminPassword" = ""
        }
        "managedIdentity" = @{
            "type" = "None"             # None, SystemAssigned or UserAssigned
            "name" = ""
            "resourceGroupName" = $resourceGroup.name
        }
        "scriptExtension" = @{          # https://docs.microsoft.com/azure/virtual-machines/extensions/custom-script-linux
            "enable" = $false           # https://docs.microsoft.com/azure/virtual-machines/extensions/custom-script-windows
            "command" = ""
            "parameters" = ""
            "teradiciLicenseKey" = ""
        }
        "publicAddress" = @{            # https://docs.microsoft.com/azure/virtual-network/public-ip-addresses
            "enable" = $false
            "type" = "Standard"
            "allocationMethod" = "Static"
        }
        "networkSecurityRules" = @(     # https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview
            @{
                "name" = "TCP"
                "access" = "Allow"
                "priority" = 100
                "protocol" = "TCP"
                "direction" = "Inbound"
                "sourcePort" = "*"
                "sourceAddress" = "*"
                "destinationPorts" = @(
                )
                "destinationAddress" = "*"
            },
            @{
                "name" = "UDP"
                "access" = "Allow"
                "priority" = 200
                "protocol" = "UDP"
                "direction" = "Inbound"
                "sourcePort" = "*"
                "sourceAddress" = "*"
                "destinationPorts" = @(
                )
                "destinationAddress" = "*"
            }
        )
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

if ($virtualMachine.managedIdentity.type -eq "UserAssigned") {
    az identity create --resource-group $virtualMachine.managedIdentity.resourceGroupName --name $virtualMachine.managedIdentity.name
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

if ($virtualMachine.image.name -ne "") {
    $image = (az image show --resource-group $virtualMachine.image.resourceGroupName --name $virtualMachine.image.name) | ConvertFrom-Json
    $osType = $image.storageProfile.osDisk.osType
} elseif ($virtualMachine.image.galleryName -ne "") {
    $imageDefinition = (az sig image-definition show --resource-group $virtualMachine.image.resourceGroupName --gallery-name $virtualMachine.image.galleryName --gallery-image-definition $virtualMachine.image.definitionName) | ConvertFrom-Json
    $osType = $imageDefinition.osType
} else {
    $imageId = $virtualMachine.image.publisher + ":" + $virtualMachine.image.offer + ":" + $virtualMachine.image.sku + ":" + $virtualMachine.image.version
    $image = (az vm image show --urn $imageId) | ConvertFrom-Json
    $osType = $image.osDiskImage.operatingSystem
}

if ($virtualMachine.publicAddress.enable) {
    if ($osType -eq "Windows") {
        $virtualMachine.networkSecurityRules[0].destinationPorts += 3389    # RDP
    } else {
        $virtualMachine.networkSecurityRules[0].destinationPorts += 22      # SSH
    }
}

if ($virtualMachine.scriptExtension.enable) {
    if ($virtualMachine.scriptExtension.teradiciLicenseKey -ne "") {
        $virtualMachine.networkSecurityRules[0].destinationPorts += 443
        $virtualMachine.networkSecurityRules[0].destinationPorts += 4172
        $virtualMachine.networkSecurityRules[0].destinationPorts += 60443
        $virtualMachine.networkSecurityRules[1].destinationPorts += 4172
    }
    if ($osType -eq "Windows") {
        $scriptParameters = "-teradiciLicenseKey " + $virtualMachine.scriptExtension.teradiciLicenseKey
        $scriptCommand = Get-ScriptCommand "$PSScriptRoot/Customize.ps1" $scriptParameters
    } else {
        $scriptParameters = "teradiciLicenseKey=" + $virtualMachine.scriptExtension.teradiciLicenseKey
        $scriptCommand = Get-ScriptCommand "$PSScriptRoot/Customize.sh" $scriptParameters
    }
    $virtualMachine.scriptExtension.command = $scriptCommand
    $virtualMachine.scriptExtension.parameters = $scriptParameters
}

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.virtualMachine.value = $virtualMachine
$templateConfig.parameters.virtualNetwork.value = $virtualNetwork
$templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
