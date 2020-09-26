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

$templateFile = "$templateDirectory/Identity.json"
$templateParameters = "$templateDirectory/Identity.Parameters.json"

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$userIdentity = $groupDeployment.properties.outputs.userIdentity.value

# Images
$resourceGroupNameSuffix = ".Images"
$resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix

$resourceGroupExists = az group exists --resource-group $resourceGroupName
if ($resourceGroupExists -eq "true") {
    $imageTemplates = (Get-Content -Path "$templateDirectory/Images.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
    foreach ($imageTemplate in $imageTemplates) {
        if ($imageTemplate.deploy) {
            az image builder delete --resource-group $resourceGroupName --name $imageTemplate.name
        }
    }
} else {
    az group create --resource-group $resourceGroupName --location $deploymentRegionName
}

$roleAssignments = (Get-Content -Path "$templateDirectory/Images.Parameters.json" -Raw | ConvertFrom-Json).parameters.roleAssignments.value
foreach ($roleAssignment in $roleAssignments.images) {
    az role assignment create --resource-group $resourceGroupName --assignee $userIdentity.principalId --role $roleAssignment
}
foreach ($roleAssignment in $roleAssignments.network) {
    az role assignment create --resource-group $virtualNetworkResourceGroupName --assignee $userIdentity.principalId --role $roleAssignment
}

$templateFile = "$templateDirectory/Images.json"
$templateParameters = "$templateDirectory/Images.Parameters.json"

$overrideParameters = '{\"userIdentity\":{\"value\":{\"name\":\"' + $userIdentity.name + '\",\"resourceGroupName\":\"' + $userIdentity.resourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"virtualNetwork\":{\"value\":{\"name\":\"' + $virtualNetworkName + '\",\"subnetName\":\"' + $virtualNetworkSubnetName + '\",\"resourceGroupName\":\"' + $virtualNetworkResourceGroupName + '\"}}}'

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters) | ConvertFrom-Json

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value

$imageTemplates = $groupDeployment.properties.outputs.imageTemplates.value
foreach ($imageTemplate in $imageTemplates) {
    if ($imageTemplate.deploy) {
        az sig image-version delete --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageTemplate.imageDefinitionName --gallery-image-version $imageTemplate.imageOutputVersion
        az image builder run --resource-group $resourceGroupName --name $imageTemplate.name
    }
}

# Machines
$resourceGroupNameSuffix = ".Machines"
$resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix

$customExtension = (Get-Content -Path "$templateDirectory/Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters.customExtension.value

$extensionFilePath = "$templateDirectory/" + $customExtension.linux.fileName
$extensionFileParameters = $customExtension.linux.fileParameters
$extensionScript = Get-Content -Path $extensionFilePath -Raw
$extensionScriptCommands = [System.Text.Encoding]::Unicode.GetBytes($extensionScript)
$extensionCommandsLinux = [Convert]::ToBase64String($extensionScriptCommands)
$extensionParametersLinux = $extensionFileParameters

$extensionFilePath = "$templateDirectory/" + $customExtension.windows.fileName
$extensionFileParameters = $customExtension.windows.fileParameters
$extensionScript = Get-Content -Path $extensionFilePath -Raw
$extensionScript = "& {" + $extensionScript + "} " + $extensionFileParameters
$extensionScriptCommands = [System.Text.Encoding]::Unicode.GetBytes($extensionScript)
$extensionCommandsWindows = [Convert]::ToBase64String($extensionScriptCommands)
$extensionParametersWindows = ""

az group create --resource-group $resourceGroupName --location $deploymentRegionName

$templateFile = "$templateDirectory/Machines.json"
$templateParameters = "$templateDirectory/Machines.Parameters.json"

$overrideParameters = '{\"userIdentity\":{\"value\":{\"name\":\"' + $userIdentity.name + '\",\"resourceGroupName\":\"' + $userIdentity.resourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"imageGallery\":{\"value\":{\"name\":\"' + $imageGallery.name + '\",\"resourceGroupName\":\"' + $imageGallery.resourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"virtualNetwork\":{\"value\":{\"name\":\"' + $virtualNetworkName + '\",\"subnetName\":\"' + $virtualNetworkSubnetName + '\",\"resourceGroupName\":\"' + $virtualNetworkResourceGroupName + '\"}}'
$overrideParameters = $overrideParameters + ',\"customExtension\":{\"value\":{\"linux\":{\"scriptCommands\":\"' + $extensionCommandsLinux + '\",\"scriptParameters\":\"' + $extensionParametersLinux + '\"},\"windows\":{\"scriptCommands\":\"' + $extensionCommandsWindows + '\",\"scriptParameters\":\"' + $extensionParametersWindows + '\"}}}}'

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters) | ConvertFrom-Json
