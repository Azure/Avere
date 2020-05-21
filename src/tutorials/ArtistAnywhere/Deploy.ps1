param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("WestUS2"),

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $storageRegionNames = @("WestUS2"),

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageNetAppEnable = $false,

	# Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageObjectEnable = $false,

	# Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview)
	[boolean] $cacheEnable = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
$moduleName = "* - Shared Services Job"
New-TraceMessage $moduleName $false
$sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $cacheEnable
$sharedServices = Receive-Job -Job $sharedServicesJob -Wait
if ($sharedServicesJob.JobStateInfo.State -eq "Failed") {
	Write-Host $sharedServicesJob.JobStateInfo.Reason
	return
}
New-TraceMessage $moduleName $true

$computeNetworks = $sharedServices.computeNetworks
$managedIdentity = $sharedServices.managedIdentity
$logAnalytics = $sharedServices.logAnalytics
$imageGallery = $sharedServices.imageGallery
$storageMounts = $sharedServices.storageMounts
$cacheMounts = $sharedServices.cacheMounts

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
New-TraceMessage $moduleName $false
$renderManagersJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderManager.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $cacheEnable, $sharedServices

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
New-TraceMessage $moduleName $false
$artistDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $cacheEnable, $sharedServices

$moduleDirectory = "RenderWorker"

# 08.0 - Worker Image Template
$computeRegionIndex = 0
$moduleName = "08.0 - Worker Image Template"
$resourceGroupNameSuffix = "Image"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory/$moduleDirectory/08-Worker.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/08-Worker.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.renderWorker.value.userIdentityId -eq "") {
	$templateParameters.renderWorker.value.userIdentityId = $managedIdentity.userResourceId
}
for ($machineImageIndex = 0; $machineImageIndex -lt $templateParameters.renderWorker.value.machineImages.length; $machineImageIndex++) {
	if ($templateParameters.renderWorker.value.machineImages[$machineImageIndex].customizePipeline[1].inline.length -eq 0) {
		$imageDefinitionName = $templateParameters.renderWorker.value.machineImages[$machineImageIndex].definitionName
		$mountCommands = Get-FileSystemMountCommands $imageGallery $imageDefinitionName $storageMounts
		$templateParameters.renderWorker.value.machineImages[$machineImageIndex].customizePipeline[1].inline = $mountCommands
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
# if (!$groupDeployment) { return } TODO: Uncomment and retest AIB idempotency!
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 08.1 - Worker Image Version
$computeRegionIndex = 0
$moduleName = "08.1 - Worker Image Version"
$resourceGroupNameSuffix = "Image"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/08-Worker.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($machineImage in $templateParameters.renderWorker.value.machineImages) {
	if ($machineImage.enabled) {
		New-TraceMessage "$moduleName [$($machineImage.templateName)]" $false $computeRegionNames[$computeRegionIndex]
		$imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
		if (!$imageVersionId) {
			az image builder run --resource-group $resourceGroupName --name $machineImage.templateName
		}
		New-TraceMessage "$moduleName [$($machineImage.templateName)]" $true $computeRegionNames[$computeRegionIndex]
	}
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
$renderManagers = Receive-Job -Job $renderManagersJob -Wait
if ($renderManagersJob.JobStateInfo.State -eq "Failed") {
	Write-Host $renderManagersJob.JobStateInfo.Reason
	return
}
New-TraceMessage $moduleName $true

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
$artistDesktopImages = Receive-Job -Job $artistDesktopImagesJob -Wait
if ($artistDesktopImagesJob.JobStateInfo.State -eq "Failed") {
	Write-Host $artistDesktopImagesJob.JobStateInfo.Reason
	return
}
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
New-TraceMessage $moduleName $false
$artistDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $cacheEnable, $sharedServices, $renderManagers

# 09 - Worker Machines
$moduleName = "09 - Worker Machines"
$resourceGroupNameSuffix = "Worker"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionIndex
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory/$moduleDirectory/09-Worker.Machines.json"
	$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/09-Worker.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
	$scriptCommands = Get-ScriptCommands "$templateDirectory/$moduleDirectory/09-Worker.Machines.sh"

	if ($templateParameters.renderWorker.value.image.referenceId -eq "") {
		$imageTemplateName = $templateParameters.renderWorker.value.image.templateName
		$imageDefinitionName = $templateParameters.renderWorker.value.image.definitionName
		$imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
		$templateParameters.renderWorker.value.image.referenceId = $imageVersionId
	}
	if ($templateParameters.renderWorker.value.scriptCommands -eq "") {
		$templateParameters.renderWorker.value.scriptCommands = $scriptCommands
	}
	if ($templateParameters.renderWorker.value.fileSystemMounts -eq "") {
		$fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
		$templateParameters.renderWorker.value.fileSystemMounts = $fileSystemMounts
	}
	if ($templateParameters.renderManager.value.hostAddress -eq "") {
		$templateParameters.renderManager.value.hostAddress = $renderManagers[$computeRegionIndex]
	}
	# if ($templateParameters.logAnalytics.value.workspaceId -eq "") {
	# 	$templateParameters.logAnalytics.value.workspaceId = $logAnalytics.workspaceId
	# }
	# if ($templateParameters.logAnalytics.value.workspaceKey -eq "") {
	# 	$templateParameters.logAnalytics.value.workspaceKey = $logAnalytics.workspaceKey
	# }
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}

	$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
	$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
$artistDesktopMachines = Receive-Job -Job $artistDesktopMachinesJob -Wait
if ($artistDesktopMachinesJob.JobStateInfo.State -eq "Failed") {
	Write-Host $artistDesktopMachinesJob.JobStateInfo.Reason
	return
}
New-TraceMessage $moduleName $true
