param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name(s) for Compute resources (e.g., Shared Image Gallery, Container Registry, etc.)
    [string[]] $computeRegionNames = @("WestUS2")
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
    $templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

$moduleDirectory = "StudioServices"

# 00 - Network
$computeNetworks = @()
$moduleName = "00 - Network"
$resourceGroupNameSuffix = ".Network"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    $computeRegionName = $computeRegionNames[$computeRegionIndex]
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/00-Network.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/00-Network.Parameters.$computeRegionName.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $computeNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
    $computeNetwork | Add-Member -MemberType NoteProperty -Name "regionName" -Value $computeRegionName
    $computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    $computeNetworks += $computeNetwork
    New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

# 01 - Security
$computeRegionIndex = 0
$computeRegionName = $computeRegionNames[$computeRegionIndex]
$moduleName = "01 - Security"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/01-Security.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/01-Security.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$userIdentity = $groupDeployment.properties.outputs.userIdentity.value
$userIdentity | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
$logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
$keyVault = $groupDeployment.properties.outputs.keyVault.value
New-TraceMessage $moduleName $true $computeRegionName

$moduleDirectory = "ImageLibrary"

# 02 - Image Gallery
$computeRegionIndex = 0
$computeRegionName = $computeRegionNames[$computeRegionIndex]
$moduleName = "02 - Image Gallery"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/02-Image.Gallery.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/02-Image.Gallery.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.userIdentity.value.principalId -eq "") {
    $templateParameters.userIdentity.value.principalId = $userIdentity.principalId
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value
$imageGallery | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $computeRegionName

# 03 - Image Registry
$computeRegionIndex = 0
$computeRegionName = $computeRegionNames[$computeRegionIndex]
$moduleName = "03 - Image Registry"
$resourceGroupNameSuffix = ".Registry"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/03-Image.Registry.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/03-Image.Registry.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.userIdentity.value.resourceId -eq "") {
    $templateParameters.userIdentity.value.resourceId = $userIdentity.resourceId
}
if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$imageRegistry = $groupDeployment.properties.outputs.imageRegistry.value
$imageRegistry | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $computeRegionName

$sharedServices = New-Object PSObject
$sharedServices | Add-Member -MemberType NoteProperty -Name "computeNetworks" -Value $computeNetworks
$sharedServices | Add-Member -MemberType NoteProperty -Name "userIdentity" -Value $userIdentity
$sharedServices | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
$sharedServices | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
$sharedServices | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
$sharedServices | Add-Member -MemberType NoteProperty -Name "imageRegistry" -Value $imageRegistry

Write-Output -InputObject $sharedServices -NoEnumerate
