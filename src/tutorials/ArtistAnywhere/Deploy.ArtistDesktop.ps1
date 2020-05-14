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
	$sharedServices = Receive-Job -Job $sharedServicesJob -Wait
	if ($sharedServicesJob.JobStateInfo.State -eq "Failed") {
		Write-Host $sharedServicesJob.JobStateInfo.Reason
		return
	}
	New-TraceMessage $moduleName $true
}

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
New-TraceMessage $moduleName $false
$artistDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $sharedServices
$artistDesktopImages = Receive-Job -Job $artistDesktopImagesJob -Wait
if ($artistDesktopImagesJob.JobStateInfo.State -eq "Failed") {
	Write-Host $artistDesktopImagesJob.JobStateInfo.Reason
	return
}
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
New-TraceMessage $moduleName $false
$artistDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $sharedServices, $renderManagers
$artistDesktopMachines = Receive-Job -Job $artistDesktopMachinesJob -Wait
if ($artistDesktopMachinesJob.JobStateInfo.State -eq "Failed") {
	Write-Host $artistDesktopMachinesJob.JobStateInfo.Reason
	return
}
New-TraceMessage $moduleName $true
