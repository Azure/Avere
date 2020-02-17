# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.0.81 (or greater) of the Azure CLI installed for this script to run properly.
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

	# Set to true to register Azure Virtual Desktop (http://docs.microsoft.com/azure/virtual-desktop/overview) render clients
	[boolean] $virtualDesktopRegister = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory\Deploy.psm1"

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

# 01 - Security
$computeRegionIndex = 0
$moduleName = "01 - Security"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Security"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\01-Security.json"
$templateParameters = (Get-Content "$templateDirectory\01-Security.Parameters.json" -Raw | ConvertFrom-Json).parameters
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

# 02 - Image
$computeRegionIndex = 0
$moduleName = "02 - Image"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\02-Image.json"
$templateParameters = "$templateDirectory\02-Image.Parameters.json"
$groupDeployment = az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
if (!$groupDeployment) { return }

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value
$imageRegistry = $groupDeployment.properties.outputs.imageRegistry.value
$imageDefinition = Get-ImageDefinition $imageGallery "Render"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

# * - Background Jobs
$moduleName = "* - Background Jobs"
New-TraceMessage $moduleName $true
$storageCacheJob = Start-Job -FilePath "$templateDirectory\Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $storageDeployNetApp, $storageDeployObject
$renderManagerJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderManager.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $imageGallery, $imageRegistry
$renderClientJob = Start-Job -FilePath "$templateDirectory\Deploy.RenderClient.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $computeNetworks, $imageGallery, $imageRegistry

$templateDirectory += "\RenderWorker"

# 08.0 - Worker Image Template
$computeRegionIndex = 0
$moduleName = "08.0 - Worker Image Template"
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Image"
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory\08-Worker.Image.json"
$templateParameters = (Get-Content "$templateDirectory\08-Worker.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters
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

# * - Background Jobs
$moduleName = "* - Background Jobs"
$storageCaches = Receive-Job -InstanceId $storageCacheJob.InstanceId -Wait
if (!$storageCaches) { return }
$renderManagers = Receive-Job -InstanceId $renderManagerJob.InstanceId -Wait
if (!$renderManagers) { return }
New-TraceMessage $moduleName $false

# 09 - Worker Machines
$moduleName = "09 - Worker Machines"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Worker"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\09-Worker.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory\09-Worker.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$machineExtensionScript = Get-MachineExtensionScript "$templateDirectory\09-Worker.Machines.sh"
	if ($templateParameters.cacheMounts.value -eq "") {
		$templateParameters.cacheMounts.value = Get-CacheMounts $storageCaches[$computeRegionIndex]
	}
	if ($templateParameters.renderWorker.value.renderManagerHost -eq "") {
		$templateParameters.renderWorker.value.renderManagerHost = $renderManagers[$computeRegionIndex]
	}
	if ($templateParameters.renderWorker.value.homeDirectory -eq "") {
		$templateParameters.renderWorker.value.homeDirectory = $imageDefinition.homeDirectory
	}
	if ($templateParameters.renderWorker.value.imageVersionId -eq "") {
		$templateParameters.renderWorker.value.imageVersionId = $imageVersion.id
	}
	if ($templateParameters.renderWorker.value.logAnalyticsWorkspaceId -eq "") {
		$templateParameters.renderWorker.value.logAnalyticsWorkspaceId = $using:logAnalyticsWorkspaceId
	}
	if ($templateParameters.renderWorker.value.logAnalyticsWorkspaceKey -eq "") {
		$templateParameters.renderWorker.value.logAnalyticsWorkspaceKey = $using:logAnalyticsWorkspaceKey
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

$renderClients = Receive-Job -InstanceId $renderClientJob.InstanceId -Wait
if (!$renderClients) { return }

if ($virtualDesktopRegister) {
	# TODO: Enable render clients via Azure Virtual Desktop service
}
