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
	
	# The set of shared Azure services across regions, including Storage, Cache, Image Gallery, etc.
	[object] $sharedServices
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
if (!$sharedServices) {
	$moduleName = "* - Shared Services Job"
	New-TraceMessage $moduleName $false
	$sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable
	$sharedServices = Receive-Job -InstanceId $sharedServicesJob.InstanceId -Wait
	if (!$sharedServices) { return }
	New-TraceMessage $moduleName $true
}

# * - Render Desktop Images Job
$moduleName = "* - Render Desktop Images Job"
New-TraceMessage $moduleName $false
$renderDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $sharedServices
$renderDesktopImages = Receive-Job -InstanceId $renderDesktopImagesJob.InstanceId -Wait
if (!$renderDesktopImages) { return }
New-TraceMessage $moduleName $true

# * - Render Desktop Machines Job
$moduleName = "* - Render Desktop Machines Job"
New-TraceMessage $moduleName $false
$renderDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $sharedServices, $renderManagers
$renderDesktopMachines = Receive-Job -InstanceId $renderDesktopMachinesJob.InstanceId -Wait
if (!$renderDesktopMachines) { return }
New-TraceMessage $moduleName $true
