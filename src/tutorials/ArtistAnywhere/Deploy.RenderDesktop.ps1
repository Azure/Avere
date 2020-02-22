# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.1.0 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix,

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames,

	# Set to the Azure Networking resources (Virtual Network, Private DNS, etc.) for compute regions
	[object[]] $computeNetworks,

	# Set to the Azure Shared Image Gallery (SIG) resource that is shared across the compute regions
	[object] $imageGallery,

	# Set to the Azure Contrainer Registry (ACR) resource that is shared across the compute regions
	[object] $imageRegistry
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory\Deploy.psm1"

$templateDirectory += "\RenderDesktop"

$imageDefinition = Get-ImageDefinition $imageGallery "Desktop"

# 10.0 - Desktop Image Template
$computeRegionIndex = 0
$moduleName = "10.0 - Desktop Image Template"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\10-Desktop.Image.json"
$templateParameters = (Get-Content "$templateDirectory\10-Desktop.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $imageDefinition
$templateParameters | Add-Member -MemberType NoteProperty -Name "imageDefinition" -Value $templateParameter
if ($templateParameters.imageBuilder.value.imageGalleryName -eq "") {
	$templateParameters.imageBuilder.value.imageGalleryName = $imageGallery.name
}
$templateParameters.imageBuilder.value.imageReplicationRegions += Get-RegionNames $computeRegionNames
$imageTemplateName = $templateParameters.imageBuilder.value.imageTemplateName
$imageTemplateResourceType = "Microsoft.VirtualMachineImages/imageTemplates"
$imageTemplates = az resource list --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName | ConvertFrom-Json
if ($imageTemplates.length -eq 0) {	
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 3).Replace('"', '\"')
	$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }
}
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# 10.1 - Desktop Image Version
$computeRegionIndex = 0
$moduleName = "10.1 - Desktop Image Version"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$imageVersion = Get-ImageVersion $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
if (!$imageVersion) {
	$imageVersion = az resource invoke-action --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName --action Run | ConvertFrom-Json
	if (!$imageVersion) { return }
	$imageVersion = Get-ImageVersion $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
}
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# 11 - Desktop Machines
$renderDesktops = @()
$moduleName = "11 - Desktop Machines"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Desktop"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\11-Desktop.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory\11-Desktop.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$machineExtensionScript = Get-MachineExtensionScript "$templateDirectory\11-Desktop.Machines.ps1"
	if ($templateParameters.renderDesktop.value.renderManagerHost -eq "") {
		$templateParameters.renderDesktop.value.renderManagerHost = $renderManagers[$computeRegionIndex]
	}
	if ($templateParameters.renderDesktop.value.imageVersionId -eq "") {
		$templateParameters.renderDesktop.value.imageVersionId = $imageVersion.id
	}
	if ($templateParameters.renderDesktop.value.logAnalyticsWorkspaceId -eq "") {
		$templateParameters.renderDesktop.value.logAnalyticsWorkspaceId = $using:logAnalyticsWorkspaceId
	}
	if ($templateParameters.renderDesktop.value.logAnalyticsWorkspaceKey -eq "") {
		$templateParameters.renderDesktop.value.logAnalyticsWorkspaceKey = $using:logAnalyticsWorkspaceKey
	}
	if ($templateParameters.renderDesktop.value.machineExtensionScript -eq "") {
		$templateParameters.renderDesktop.value.machineExtensionScript = $machineExtensionScript
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
	$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$renderDesktops += $groupDeployment.properties.outputs.renderDesktops.value
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

Write-Output -InputObject $renderDesktops -NoEnumerate
