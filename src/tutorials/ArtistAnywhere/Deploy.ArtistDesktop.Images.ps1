param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix,

    # Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
    [string[]] $computeRegionNames = @("WestUS2"),

    # Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
    [string[]] $storageRegionNames = @("WestUS2"),

    # Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
    [boolean] $storageObjectEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview)
    [boolean] $cacheEnable = $false,

    # The set of shared Azure services across regions, including Storage, Cache, Image Gallery, etc.
    [object] $sharedServices
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
    $templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
if (!$sharedServices) {
    $moduleName = "* - Shared Services Job"
    New-TraceMessage $moduleName $false
    $sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $cacheEnable
    $sharedServices = Receive-Job -Job $sharedServicesJob -Wait
    if ($sharedServicesJob.JobStateInfo.State -eq "Failed") {
        Write-Host $sharedServicesJob.JobStateInfo.Reason
        return
    }
    New-TraceMessage $moduleName $true
}

$computeNetworks = $sharedServices.computeNetworks
$managedIdentity = $sharedServices.managedIdentity
$imageGallery = $sharedServices.imageGallery
$storageMounts = $sharedServices.storageMounts

$moduleDirectory = "ArtistDesktop"

# 10.0 - Desktop Image Template
$computeRegionIndex = 0
$moduleName = "10.0 - Desktop Image Template"
$resourceGroupNameSuffix = "Image"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory/$moduleDirectory/10-Desktop.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/10-Desktop.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.artistDesktop.value.userIdentityId -eq "") {
    $templateParameters.artistDesktop.value.userIdentityId = $managedIdentity.userResourceId
}
for ($machineImageIndex = 0; $machineImageIndex -lt $templateParameters.artistDesktop.value.machineImages.length; $machineImageIndex++) {
    if ($templateParameters.artistDesktop.value.machineImages[$machineImageIndex].customizePipeline[1].inline.length -eq 0) {
        $imageDefinitionName = $templateParameters.artistDesktop.value.machineImages[$machineImageIndex].definitionName
        $mountCommands = Get-FileSystemMountCommands $imageGallery $imageDefinitionName $storageMounts
        $templateParameters.artistDesktop.value.machineImages[$machineImageIndex].customizePipeline[1].inline = $mountCommands
    }
}
if ($templateParameters.imageGallery.value.name -eq "") {
    $templateParameters.imageGallery.value.name = $imageGallery.name
}
if ($templateParameters.imageGallery.value.imageReplicationRegions.length -eq 0) {
    $templateParameters.imageGallery.value.imageReplicationRegions = $computeRegionNames
}
if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 7).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
# if (!$groupDeployment) { return }
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 10.1 - Desktop Image Version
$artistDesktopImages = @()
$computeRegionIndex = 0
$moduleName = "10.1 - Desktop Image Version"
$resourceGroupNameSuffix = "Image"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/10-Desktop.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($machineImage in $templateParameters.artistDesktop.value.machineImages) {
    if ($machineImage.enabled) {
        New-TraceMessage "$moduleName [$($machineImage.templateName)]" $false $computeRegionNames[$computeRegionIndex]
        $imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
        if (!$imageVersionId) {
            az image builder run --resource-group $resourceGroupName --name $machineImage.templateName
        }
        $artistDesktopImages += $machineImage
        New-TraceMessage "$moduleName [$($machineImage.templateName)]" $true $computeRegionNames[$computeRegionIndex]
    }
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

Write-Output -InputObject $artistDesktopImages -NoEnumerate
