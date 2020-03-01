# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.1.0 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("West US 2", "East US 2"),

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageDeployNetApp = $false,

	# Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageDeployObject = $false,

	# Set to true to deploy Azure Virtual Desktop (http://docs.microsoft.com/azure/virtual-desktop/overview) host pool
	[boolean] $virtualDesktopDeploy = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory\Deploy.psm1"

# * - Image Gallery Job
$moduleName = "* - Image Gallery Job"
New-TraceMessage $moduleName $true
$imageGalleryJob = Start-Job -FilePath "$templateDirectory\Deploy.ImageGallery.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames

# 00 - Network
$computeNetworks = @()
$moduleName = "00 - Network"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Network"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\00-Network.json"
	$templateParameters = "$templateDirectory\00-Network.Parameters.Region$computeRegionIndex.json"
	$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$computeNetwork = New-Object PSObject
	$computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
	$computeNetwork | Add-Member -MemberType NoteProperty -Name "name" -Value $groupDeployment.properties.outputs.virtualNetworkName.value
	$computeNetwork | Add-Member -MemberType NoteProperty -Name "domainName" -Value $groupDeployment.properties.outputs.virtualNetworkDomainName.value
	$computeNetworks += $computeNetwork
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

# 02 - Security
$computeRegionIndex = 0
$moduleName = "02 - Security"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Security"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\02-Security.json"
$templateParameters = (Get-Content "$templateDirectory\02-Security.Parameters.json" -Raw | ConvertFrom-Json).parameters
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
	$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}
if ($templateParameters.virtualNetwork.value.name -eq "") {
	$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
if (!$groupDeployment) { return }

$logAnalyticsWorkspaceId = $groupDeployment.properties.outputs.logAnalyticsWorkspaceId.value
$logAnalyticsWorkspaceKey = $groupDeployment.properties.outputs.logAnalyticsWorkspaceKey.value
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# * - Image Gallery Job
$moduleName = "* - Image Gallery Job"
$imageGallery = Receive-Job -InstanceId $imageGalleryJob.InstanceId -Wait
New-TraceMessage $moduleName $false

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
New-TraceMessage $moduleName $true
$storageCacheJob = Start-Job -FilePath "$templateDirectory\Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $storageDeployNetApp, $storageDeployObject

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
New-TraceMessage $moduleName $true
$renderManagerJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderManager.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $imageGallery

# * - Render Desktop Image Job
$moduleName = "* - Render Desktop Image Job"
New-TraceMessage $moduleName $true
$renderDesktopImageJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderDesktop.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $imageGallery

$moduleDirectory = "RenderWorker"

$imageDefinition = Get-ImageDefinition $imageGallery "Render"

# 08.0 - Worker Image Template
$computeRegionIndex = 0
$moduleName = "08.0 - Worker Image Template"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\$moduleDirectory\08-Worker.Image.json"
$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\08-Worker.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
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

# 08.1 - Worker Image Version
$computeRegionIndex = 0
$moduleName = "08.1 - Worker Image Version"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$imageVersion = Get-ImageVersion $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
if (!$imageVersion) {
	$imageVersion = az resource invoke-action --resource-group $resourceGroupName --resource-type $imageTemplateResourceType --name $imageTemplateName --action Run | ConvertFrom-Json
	if (!$imageVersion) { return }
	$imageVersion = Get-ImageVersion $resourceGroupName $imageGallery.name $imageDefinition.name $imageTemplateName
}
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
$storageCaches = Receive-Job -InstanceId $storageCacheJob.InstanceId -Wait
if (!$storageCaches) { return }
New-TraceMessage $moduleName $false

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
$renderManagers = Receive-Job -InstanceId $renderManagerJob.InstanceId -Wait
if (!$renderManagers) { return }
New-TraceMessage $moduleName $false

# * - Render Desktop Image Job
$moduleName = "* - Render Desktop Image Job"
$renderDesktopImage = Receive-Job -InstanceId $renderDesktopImageJob.InstanceId -Wait
if (!$renderDesktopImage) { return }
New-TraceMessage $moduleName $false

# * - Render Desktop Machines Job
$moduleName = "* - Render Desktop Machines Job"
New-TraceMessage $moduleName $true
$renderDesktopMachinesJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $renderManagers, $renderDesktopImage

# 09 - Worker Machines
$moduleName = "09 - Worker Machines"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Worker"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\$moduleDirectory\09-Worker.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\09-Worker.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$machineExtensionScript = Get-MachineExtensionScript "$templateDirectory\$moduleDirectory\09-Worker.Machines.sh"
	if ($templateParameters.cacheMounts.value -eq "") {
		$templateParameters.cacheMounts.value = Get-CacheMounts $storageCaches[$computeRegionIndex]
	}
	if ($templateParameters.renderManager.value.hostAddress -eq "") {
		$templateParameters.renderManager.value.hostAddress = $renderManagers[$computeRegionIndex]
	}
	if ($templateParameters.renderWorker.value.homeDirectory -eq "") {
		$templateParameters.renderWorker.value.homeDirectory = $imageDefinition.homeDirectory
	}
	if ($templateParameters.renderWorker.value.imageVersionId -eq "") {
		$templateParameters.renderWorker.value.imageVersionId = $imageVersion.id
	}
	if ($templateParameters.renderWorker.value.logAnalyticsWorkspaceId -eq "") {
		$templateParameters.renderWorker.value.logAnalyticsWorkspaceId = $logAnalyticsWorkspaceId
	}
	if ($templateParameters.renderWorker.value.logAnalyticsWorkspaceKey -eq "") {
		$templateParameters.renderWorker.value.logAnalyticsWorkspaceKey = $logAnalyticsWorkspaceKey
	}
	if ($templateParameters.renderWorker.value.machineExtensionScript -eq "") {
		$templateParameters.renderWorker.value.machineExtensionScript = $machineExtensionScript
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
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

# * - Render Desktop Machines Job
$moduleName = "* - Render Desktop Machines Job"
$renderDesktopMachines = Receive-Job -InstanceId $renderDesktopMachinesJob.InstanceId -Wait
if (!$renderDesktopMachines) { return }
New-TraceMessage $moduleName $false

# 12 - Virtual Desktop Pool
if ($virtualDesktopDeploy) {
	$moduleName = "12 - Virtual Desktop Pool"
	New-TraceMessage $moduleName $true
	for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
		New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
		$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Desktop"
		$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
		if (!$resourceGroup) { return }
	
		$templateResources = "$templateDirectory\$moduleDirectory\12-Desktop.Pool.json"
		$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\12-Desktop.Pool.Parameters.json" -Raw | ConvertFrom-Json).parameters

		$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
		$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
		if (!$groupDeployment) { return }
		New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
	}
	New-TraceMessage $moduleName $false
}
