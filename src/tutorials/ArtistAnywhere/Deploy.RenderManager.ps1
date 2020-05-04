param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix,

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames,

	# Set to the Azure Networking resources (Virtual Network, Private DNS, etc.) for compute regions
	[object[]] $computeNetworks,

	# Set to the Azure Shared Image Gallery (SIG) resource that is shared across the compute regions
	[object] $imageGallery,

	# Set to the Azure Monitor Log Analytics resource that is shared across the compute regions
	[object] $logAnalytics
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

$moduleDirectory = "RenderManager"

# 05 - Manager Data
$managerDatabaseDeploySql = @()
$managerDatabaseClientUrl = @()
$managerDatabaseClientUsername = @()
$managerDatabaseClientPassword = @()
$moduleName = "05 - Manager Data"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	$computeRegionName = $computeRegionNames[$computeRegionIndex]
	New-TraceMessage $moduleName $false $computeRegionName
	$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Manager"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
	if (!$resourceGroup) { return }
	
	$templateResources = "$templateDirectory/$moduleDirectory/05-Manager.Data.json"
	$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/05-Manager.Data.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
	$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$managerDatabaseDeploySql += $groupDeployment.properties.outputs.managerDatabaseDeploySql.value
	$managerDatabaseClientUrl += $groupDeployment.properties.outputs.managerDatabaseClientUrl.value
	$managerDatabaseClientUsername += $groupDeployment.properties.outputs.managerDatabaseClientUsername.value
	$managerDatabaseClientPassword += $groupDeployment.properties.outputs.managerDatabaseClientPassword.value
	New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

$imageDefinition = Get-ImageDefinition $imageGallery "LinuxServer"

# 06.0 - Manager Image Template
$computeRegionIndex = 0
$moduleName = "06.0 - Manager Image Template"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory/$moduleDirectory/06-Manager.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/06-Manager.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $imageDefinition
$templateParameters | Add-Member -MemberType NoteProperty -Name "imageDefinition" -Value $templateParameter
if ($templateParameters.imageBuilder.value.imageGalleryName -eq "") {
	$templateParameters.imageBuilder.value.imageGalleryName = $imageGallery.name
}
$templateParameters.imageBuilder.value.imageReplicationRegions += Get-RegionNames $computeRegionNames
$imageTemplateName = $templateParameters.imageBuilder.value.imageTemplateName
$imageTemplates = (az resource list --resource-group $resourceGroupName --resource-type "Microsoft.VirtualMachineImages/imageTemplates" --name $imageTemplateName) | ConvertFrom-Json
if ($imageTemplates.length -eq 0) {	
	$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 3).Replace('"', '\"')
	$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 06.1 - Manager Image Version
$computeRegionIndex = 0
$moduleName = "06.1 - Manager Image Version"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Image"
$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
if (!$imageVersionId) {
	az image builder run --resource-group $resourceGroupName --name $imageTemplateName
	$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
	if (!$imageVersionId) { return }
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 07 - Manager Machines
$renderManagers = @()
$moduleName = "07 - Manager Machines"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Manager"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory/$moduleDirectory/07-Manager.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/07-Manager.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$extensionScriptCommands = Get-ScriptCommands "$templateDirectory/$moduleDirectory/07-Manager.Machines.sh"
	if ($templateParameters.renderManager.value.homeDirectory -eq "") {
		$templateParameters.renderManager.value.homeDirectory = $imageDefinition.homeDirectory
	}
	if ($templateParameters.renderManager.value.imageVersionId -eq "") {
		$templateParameters.renderManager.value.imageVersionId = $imageVersionId
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
		$templateParameters.renderManager.value.logAnalyticsWorkspaceId = $logAnalytics.workspaceId
	}
	if ($templateParameters.renderManager.value.logAnalyticsWorkspaceKey -eq "") {
		$templateParameters.renderManager.value.logAnalyticsWorkspaceKey = $logAnalytics.workspaceKey
	}
	if ($templateParameters.renderManager.value.extensionScriptCommands -eq "") {
		$templateParameters.renderManager.value.extensionScriptCommands = $extensionScriptCommands
	}
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
	$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }
	
	$renderManagers += $groupDeployment.properties.outputs.renderManager.value
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

Write-Output -InputObject $renderManagers -NoEnumerate
