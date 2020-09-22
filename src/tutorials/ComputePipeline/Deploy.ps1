$deploymentRegionName = "WestUS2"
$resourceGroupNamePrefix = "ComputePipeline"

$virtualNetworkName = "MediaPipeline"
$virtualNetworkSubnetName = "Desktop"
$virtualNetworkResourceGroupName = "Azure.Media.Pipeline.WestUS2.Network"

$templateDirectory = $PSScriptRoot

# Identity
$resourceGroupNameSuffix = ".Identity"
$resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix

az group create --resource-group $resourceGroupName --location $deploymentRegionName

$templateFile = "$templateDirectory/ComputePipeline.Identity.json"
$templateParameters = "$templateDirectory/ComputePipeline.Identity.Parameters.json"

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$userIdentity = $groupDeployment.properties.outputs.userIdentity.value

# Images
$resourceGroupNameSuffix = ".Images"
$resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix

$resourceGroupExists = az group exists --resource-group $resourceGroupName
if ($resourceGroupExists -eq "true") {
    $imageTemplates = (Get-Content -Path "$templateDirectory/ComputePipeline.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
    foreach ($imageTemplate in $imageTemplates) {
        if ($imageTemplate.enabled) {
            az image builder delete --resource-group $resourceGroupName --name $imageTemplate.name
        }
    }
    az role assignment delete --assignee $userIdentity.principalId --resource-group $resourceGroupName 
    az role assignment delete --assignee $userIdentity.principalId --resource-group $virtualNetworkResourceGroupName
} else {
    az group create --resource-group $resourceGroupName --location $deploymentRegionName
}

$templateFile = "$templateDirectory/ComputePipeline.Images.json"
$templateParameters = "$templateDirectory/ComputePipeline.Images.Parameters.json"

$overrideParameters = '{\"userIdentity\":{\"value\":{\"name\":\"' + $userIdentity.name + '\",\"resourceGroupName\":\"' + $userIdentity.resourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"virtualNetwork\":{\"value\":{\"name\":\"' + $virtualNetworkName + '\",\"subnetName\":\"' + $virtualNetworkSubnetName + '\",\"resourceGroupName\":\"' + $virtualNetworkResourceGroupName + '\"}}}'

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters) | ConvertFrom-Json

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value

$imageTemplates = $groupDeployment.properties.outputs.imageTemplates.value
foreach ($imageTemplate in $imageTemplates) {
    if ($imageTemplate.enabled) {
        az sig image-version delete --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageTemplate.imageDefinitionName --gallery-image-version $imageTemplate.imageOutputVersion
        az image builder run --resource-group $resourceGroupName --name $imageTemplate.name
    }
}

# Machines
$resourceGroupNameSuffix = ".Machines"
$resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix

$templateParameters = (Get-Content -Path "$templateDirectory/ComputePipeline.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters

$extensionFilePath = "$templateDirectory/" + $templateParameters.customExtension.value.linux.fileName
$extensionFileParameters = $templateParameters.customExtension.value.linux.fileParameters
$extensionScript = Get-Content -Path $extensionFilePath -Raw
$memoryStream = New-Object System.IO.MemoryStream
$compressionStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
$streamWriter = New-Object System.IO.StreamWriter($compressionStream)
$streamWriter.Write($extensionScript)
$streamWriter.Close();
$extensionScriptCommands = $memoryStream.ToArray()
$extensionCommandsLinux = [Convert]::ToBase64String($extensionScriptCommands)
$extensionParametersLinux = $extensionFileParameters

$extensionFilePath = "$templateDirectory/" + $templateParameters.customExtension.value.windows.fileName
$extensionFileParameters = $templateParameters.customExtension.value.windows.fileParameters
$extensionScript = Get-Content -Path $extensionFilePath -Raw
$extensionScript = "& {" + $extensionScript + "} " + $extensionFileParameters
$extensionScriptCommands = [System.Text.Encoding]::Unicode.GetBytes($extensionScript)
$extensionCommandsWindows = [Convert]::ToBase64String($extensionScriptCommands)
$extensionParametersWindows = ""

az group create --resource-group $resourceGroupName --location $deploymentRegionName

$templateFile = "$templateDirectory/ComputePipeline.Machines.json"
$templateParameters = "$templateDirectory/ComputePipeline.Machines.Parameters.json"

$overrideParameters = '{\"userIdentity\":{\"value\":{\"name\":\"' + $userIdentity.name + '\",\"resourceGroupName\":\"' + $userIdentity.resourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"imageGallery\":{\"value\":{\"name\":\"' + $imageGallery.name + '\",\"resourceGroupName\":\"' + $imageGallery.resourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"virtualNetwork\":{\"value\":{\"name\":\"' + $virtualNetworkName + '\",\"subnetName\":\"' + $virtualNetworkSubnetName + '\",\"resourceGroupName\":\"' + $virtualNetworkResourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"customExtension\":{\"value\":{\"linux\":{\"executeCommands\":\"' + $extensionCommandsLinux + '\",\"executeParameters\":\"' + $extensionParametersLinux + '\"},\"windows\":{\"executeCommands\":\"' + $extensionCommandsWindows + '\",\"executeParameters\":\"' + $extensionParametersWindows + '\"}}}}'

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters) | ConvertFrom-Json
