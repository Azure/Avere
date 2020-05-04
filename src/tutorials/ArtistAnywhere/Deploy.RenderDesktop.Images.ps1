param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix,

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames,

	# Set to the Azure Shared Image Gallery (SIG) resource that is shared across the compute regions
	[object] $imageGallery
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

$moduleDirectory = "RenderDesktop"

# 10.0 - Desktop Image Template
$computeRegionIndex = 0
$moduleName = "10.0 - Desktop Image Template"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory/$moduleDirectory/10-Desktop.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/10-Desktop.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
if ($templateParameters.imageBuilder.value.imageGalleryName -eq "") {
	$templateParameters.imageBuilder.value.imageGalleryName = $imageGallery.name
}
$templateParameters.imageBuilder.value.imageReplicationRegions += Get-RegionNames $computeRegionNames

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 7).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
#if (!$groupDeployment) { return } // TODO: After AIB GA, test image template update/upgrade support!

New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 10.1 - Desktop Image Version
$imageVersionIds = @()
$computeRegionIndex = 0
$moduleName = "10.1 - Desktop Image Version"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/10-Desktop.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($machineImage in $templateParameters.renderDesktop.value.machineImages) {
	New-TraceMessage "$moduleName [$($machineImage.templateName)]" $false $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Image"
	$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
	if (!$imageVersionId -and $machineImage.enabled) {
		az image builder run --resource-group $resourceGroupName --name $machineImage.templateName
		$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
		if (!$imageVersionId) { return }
	}
	$imageVersionIds += $imageVersionId
	New-TraceMessage "$moduleName [$($machineImage.templateName)]" $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

Write-Output -InputObject $imageVersionIds -NoEnumerate
