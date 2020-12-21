param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Pipeline",

    # Set the Azure region name for shared resources (e.g., Managed Identity, Key Vault, Monitor Insight, etc.)
    [string] $sharedRegionName = "WestUS2",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machines, Batch Accounts, etc.)
    [string] $computeRegionName = "EastUS",

    # Set the Azure region name for storage cache resources (e.g., HPC Cache, Storage Targets, Namespace Paths, etc.)
    [string] $cacheRegionName = "",

    # Set the Azure region name for storage resources (e.g., Storage Accounts, File Shares, Object Containers, etc.)
    [string] $storageRegionName = "EastUS",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# Shared Framework
$sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName

# Storage Cache
$storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $cacheRegionName $storageRegionName $storageNetAppDeploy

# Artist Workstation Image Job
$moduleName = "Artist Workstation Image Job"
New-TraceMessage $moduleName $false
$workstationImageJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $cacheRegionName, $storageRegionName, $storageNetAppDeploy, $sharedFramework, $storageCache
Receive-Job -Job $workstationImageJob -Wait
New-TraceMessage $moduleName $true

# Artist Workstation Machine Job
$moduleName = "Artist Workstation Machine Job"
New-TraceMessage $moduleName $false
$workstationMachineJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $cacheRegionName, $storageRegionName, $storageNetAppDeploy, $sharedFramework, $storageCache
Receive-Job -Job $workstationMachineJob -Wait
New-TraceMessage $moduleName $true
