# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.3.1 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix,

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames,

	# Set to the Azure Networking resources (Virtual Network, Private DNS, etc.) for compute regions
	[object[]] $computeNetworks,

	# Set to the Azure Render Manager hosts (names or addresses) in each of the compute regions
	[string[]] $renderManagers,

	# Set to the Azure Monitor Log Analytics resource that is shared across the compute regions
	[object] $logAnalytics
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory\Deploy.psm1"

$moduleDirectory = "RenderDesktop"

# 11 - Desktop Machines
$renderDesktops = @()
$moduleName = "11 - Desktop Machines"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Desktop"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\$moduleDirectory\11-Desktop.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\11-Desktop.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters

	$imageGalleryResourceGroupName = $templateParameters.imageGallery.value.resourceGroupName
	$imageGalleryName = $templateParameters.imageGallery.value.name
	$renderManager = $renderManagers -and $renderManagers.length -gt $computeRegionIndex ? $renderManagers[$computeRegionIndex] : ""
	for ($machineTypeIndex = 0; $machineTypeIndex -lt $templateParameters.renderDesktop.value.machineTypes.length; $machineTypeIndex++) {
		if ($templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].image.referenceId -eq "") {
			$imageTemplateName = $templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].image.templateName
			$imageDefinitionName = $templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].image.definitionName
			$imageVersionId = Get-ImageVersionId $imageGalleryResourceGroupName $imageGalleryName $imageDefinitionName $imageTemplateName
			$templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].image.referenceId = $imageVersionId
		}
		if ($templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].extension.commandToExecute -eq "") {
			$scriptFileName = $templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].extension.scriptFile
			$scriptFilePath = "$templateDirectory\$moduleDirectory\$scriptFileName"
			$scriptParameters = $templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].extension.scriptParameters
			$scriptParameters += " " + $renderManager
			$extensionScriptData = Get-ScriptData $scriptFilePath $scriptParameters
			$extensionScriptCommand = $templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].extension.scriptCommand
			$extensionCommandToExecute = [string]::Format($extensionScriptCommand, $extensionScriptData)
			$templateParameters.renderDesktop.value.machineTypes[$machineTypeIndex].extension.commandToExecute = $extensionCommandToExecute
		}
	}
	if ($templateParameters.logAnalytics.value.workspaceId -eq "") {
		$templateParameters.logAnalytics.value.workspaceId = $logAnalytics.workspaceId
	}
	if ($templateParameters.logAnalytics.value.workspaceKey -eq "") {
		$templateParameters.logAnalytics.value.workspaceKey = $logAnalytics.workspaceKey
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
	$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$renderDesktops += $groupDeployment.properties.outputs.renderDesktops.value
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

Write-Output -InputObject $renderDesktops -NoEnumerate
