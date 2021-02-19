function Get-ImageLibrary ($rootDirectory, $baseFramework, $resourceGroupNamePrefix, $computeRegionName) {
    $computeNetwork = $baseFramework.computeNetwork
    $managedIdentity = $baseFramework.managedIdentity

    $moduleDirectory = "ImageLibrary"

    # (11) Image Gallery
    $moduleName = "(11) Image Gallery"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Gallery"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/11-ImageGallery.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/11-ImageGallery.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $imageGallery = $groupDeployment.properties.outputs.imageGallery.value
    New-TraceMessage $moduleName $true

    Set-RoleAssignments "Image Builder" $null $computeNetwork $managedIdentity $keyVault $imageGallery

    # (12) Container Registry
    $moduleName = "(12) Container Registry"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Registry"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/12-ContainerRegistry.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/12-ContainerRegistry.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $containerRegistry = $groupDeployment.properties.outputs.containerRegistry.value
    New-TraceMessage $moduleName $true

    $imageLibrary = New-Object PSObject
    $imageLibrary | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
    $imageLibrary | Add-Member -MemberType NoteProperty -Name "containerRegistry" -Value $containerRegistry
    return $imageLibrary
}
