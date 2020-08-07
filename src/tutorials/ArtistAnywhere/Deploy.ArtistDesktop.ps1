param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name for Compute resources (e.g., Image Builder, Virtual Machines, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for Storage resources (e.g., Virtual Network, Object (Blob) Storage, NetApp Files, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
$moduleName = "* - Shared Services Job"
New-TraceMessage $moduleName $false
$sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName
$sharedServices = Receive-Job -Job $sharedServicesJob -Wait
New-TraceMessage $moduleName $true

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
New-TraceMessage $moduleName $false
$storageCacheJob = Start-Job -FilePath "$templateDirectory/Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
New-TraceMessage $moduleName $false
$artistDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices
$artistDesktopImages = Receive-Job -Job $artistDesktopImagesJob -Wait
New-TraceMessage $moduleName $true

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
$storageCache = Receive-Job -Job $storageCacheJob -Wait
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
New-TraceMessage $moduleName $false
$artistDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices, $storageCache, $renderManager
$artistDesktopMachines = Receive-Job -Job $artistDesktopMachinesJob -Wait
New-TraceMessage $moduleName $true
