# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.2.0 (or greater) of the Azure CLI installed for this script to run properly.
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

$imageDefinition = Get-ImageDefinition $imageGallery "Desktop"

# 10.0 - Desktop Image Template
$computeRegionIndex = 0
$moduleName = "10.0 - Desktop Image Template"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\$moduleDirectory\10-Desktop.Image.json"
$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\10-Desktop.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $imageDefinition
$templateParameters | Add-Member -MemberType NoteProperty -Name "imageDefinition" -Value $templateParameter
if ($templateParameters.imageBuilder.value.imageGalleryName -eq "") {
	$templateParameters.imageBuilder.value.imageGalleryName = $imageGallery.name
}
$templateParameters.imageBuilder.value.imageReplicationRegions += Get-RegionNames $computeRegionNames
$imageTemplateName = $templateParameters.imageBuilder.value.imageTemplateName
$imageTemplates = az resource list --resource-group $resourceGroupName --resource-type "Microsoft.VirtualMachineImages/imageTemplates" --name $imageTemplateName | ConvertFrom-Json
if ($imageTemplates.length -eq 0) {	
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 3).Replace('"', '\"')
	$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }
}
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# 10.1 - Desktop Image Version
$computeRegionIndex = 0
$moduleName = "10.1 - Desktop Image Version"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
if (!$imageVersionId) {
	az image builder run --resource-group $resourceGroupName --name $imageTemplateName
	$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
	if (!$imageVersionId) { return }
}
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

Write-Output -InputObject $imageVersionId -NoEnumerate
