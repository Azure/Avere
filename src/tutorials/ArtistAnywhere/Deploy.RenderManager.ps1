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

$moduleDirectory = "RenderManager"

# 05 - Manager Data
$managerDatabaseDeploySql = @()
$managerDatabaseClientUrl = @()
$managerDatabaseClientUsername = @()
$managerDatabaseClientPassword = @()
$moduleName = "05 - Manager Data"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Manager"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }
	
	$templateResources = "$templateDirectory\$moduleDirectory\05-Manager.Data.json"
	$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\05-Manager.Data.Parameters.Region$computeRegionIndex.json" -Raw | ConvertFrom-Json).parameters
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
	$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$managerDatabaseDeploySql += $groupDeployment.properties.outputs.managerDatabaseDeploySql.value
	$managerDatabaseClientUrl += $groupDeployment.properties.outputs.managerDatabaseClientUrl.value
	$managerDatabaseClientUsername += $groupDeployment.properties.outputs.managerDatabaseClientUsername.value
	$managerDatabaseClientPassword += $groupDeployment.properties.outputs.managerDatabaseClientPassword.value
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

$imageDefinition = Get-ImageDefinition $imageGallery "Render"

# 06.0 - Manager Image Template
$computeRegionIndex = 0
$moduleName = "06.0 - Manager Image Template"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\$moduleDirectory\06-Manager.Image.json"
$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\06-Manager.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
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

# 06.1 - Manager Image Version
$computeRegionIndex = 0
$moduleName = "06.1 - Manager Image Version"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$imageVersion = Get-ImageVersion $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
if (!$imageVersion) {
	$imageVersion = az resource invoke-action --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName --action Run | ConvertFrom-Json
	if (!$imageVersion) { return }
	$imageVersion = Get-ImageVersion $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
}
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# 07 - Manager Machines
$renderManagers = @()
$moduleName = "07 - Manager Machines"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Manager"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\$moduleDirectory\07-Manager.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\07-Manager.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$machineExtensionScript = Get-MachineExtensionScript "$templateDirectory\$moduleDirectory\07-Manager.Machines.sh"
	if ($templateParameters.renderManager.value.homeDirectory -eq "") {
		$templateParameters.renderManager.value.homeDirectory = $imageDefinition.homeDirectory
	}
	if ($templateParameters.renderManager.value.imageVersionId -eq "") {
		$templateParameters.renderManager.value.imageVersionId = $imageVersion.id
	}
	if ($templateParameters.renderManager.value.databaseDeploySql -eq "") {
		$templateParameters.renderManager.value.databaseDeploySql = $managerDatabaseDeploySql[$computeRegionIndex]
	}
	if ($templateParameters.renderManager.value.databaseClientUrl -eq "") {
		$templateParameters.renderManager.value.databaseClientUrl = $managerDatabaseClientUrl[$computeRegionIndex]
	}
	if ($templateParameters.renderManager.value.databaseClientUsername -eq "") {
		$templateParameters.renderManager.value.databaseClientUsername = $managerDatabaseClientUsername[$computeRegionIndex]
	}
	if ($templateParameters.renderManager.value.databaseClientPassword -eq "") {
		$templateParameters.renderManager.value.databaseClientPassword = $managerDatabaseClientPassword[$computeRegionIndex]
	}
	if ($templateParameters.renderManager.value.logAnalyticsWorkspaceId -eq "") {
		$templateParameters.renderManager.value.logAnalyticsWorkspaceId = $using:logAnalyticsWorkspaceId
	}
	if ($templateParameters.renderManager.value.logAnalyticsWorkspaceKey -eq "") {
		$templateParameters.renderManager.value.logAnalyticsWorkspaceKey = $using:logAnalyticsWorkspaceKey
	}
	if ($templateParameters.renderManager.value.machineExtensionScript -eq "") {
		$templateParameters.renderManager.value.machineExtensionScript = $machineExtensionScript
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
	
	$renderManagers += $groupDeployment.properties.outputs.renderManager.value
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

Write-Output -InputObject $renderManagers -NoEnumerate
