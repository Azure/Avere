# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.3.1 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

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

Import-Module "$templateDirectory\Deploy.psm1"

$moduleDirectory = "RenderDesktop"

# 10.0 - Desktop Image Template
$computeRegionIndex = 0
$moduleName = "10.0 - Desktop Image Template"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\$moduleDirectory\10-Desktop.Image.json"
$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\10-Desktop.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
if ($templateParameters.imageBuilder.value.imageGalleryName -eq "") {
	$templateParameters.imageBuilder.value.imageGalleryName = $imageGallery.name
}
$templateParameters.imageBuilder.value.imageReplicationRegions += Get-RegionNames $computeRegionNames
foreach ($machineImage in $templateParameters.renderDesktop.value.machineImages) {
	New-TraceMessage "$moduleName [$($machineImage.templateName)]" $false $computeRegionNames[$computeRegionIndex]
	$imageTemplates = az resource list --resource-group $resourceGroupName --resource-type "Microsoft.VirtualMachineImages/imageTemplates" --name $machineImage.templateName | ConvertFrom-Json
	if ($imageTemplates.length -eq 0) {	
		$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
		$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
		if (!$groupDeployment) { return }
	}
	New-TraceMessage "$moduleName [$($machineImage.templateName)]" $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 10.1 - Desktop Image Version
$imageVersionIds = @()
$computeRegionIndex = 0
$moduleName = "10.1 - Desktop Image Version"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\10-Desktop.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($machineImage in $templateParameters.renderDesktop.value.machineImages) {
	New-TraceMessage "$moduleName [$($machineImage.templateName)]" $false $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
	$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
	if (!$imageVersionId) {
		az image builder run --resource-group $resourceGroupName --name $machineImage.templateName
		$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
		if (!$imageVersionId) { return }
	}
	$imageVersionIds += $imageVersionId
	New-TraceMessage "$moduleName [$($machineImage.templateName)]" $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

Write-Output -InputObject $imageVersionIds -NoEnumerate
