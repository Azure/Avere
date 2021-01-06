param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Pipeline",

    # Set the Azure region name for shared resources (e.g., Managed Identity, Key Vault, Monitor Insight, etc.)
    [string] $sharedRegionName = "WestUS2",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machines, Batch Accounts, etc.)
    [string] $computeRegionName = "EastUS",

    # Set the Azure region name for storage resources (e.g., Storage Accounts, File Shares, Object Containers, etc.)
    [string] $storageRegionName = "EastUS",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) in Azure compute region
    [boolean] $storageCacheDeploy = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# Shared Framework
$sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName

# Storage Cache
$storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy

# Artist Workstation Image [Linux] Job
$moduleNameImageLinux = "Artist Workstation Image [Linux] Job"
New-TraceMessage $moduleNameImageLinux $false
$workstationImageLinuxJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Image.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

# Artist Workstation Image [Windows] Job
$moduleNameImageWindows = "Artist Workstation Image [Windows] Job"
New-TraceMessage $moduleNameImageWindows $false
$workstationImageWindowsJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Image.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

Receive-Job -Job $workstationImageLinuxJob -Wait
New-TraceMessage $moduleNameImageLinux $true

# Artist Workstation Machine [Linux] Job
$moduleNameMachineLinux = "Artist Workstation Machine [Linux] Job"
New-TraceMessage $moduleNameMachineLinux $false
$workstationMachineLinuxJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Machine.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

Receive-Job -Job $workstationImageWindowsJob -Wait
New-TraceMessage $moduleNameImageWindows $true

# Artist Workstation Machine [Windows] Job
$moduleNameMachineWindows = "Artist Workstation Machine [Windows] Job"
New-TraceMessage $moduleNameMachineWindows $false
$workstationMachineWindowsJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Machine.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

Receive-Job -Job $workstationMachineLinuxJob -Wait
New-TraceMessage $moduleNameMachineLinux $true

Receive-Job -Job $workstationMachineWindowsJob -Wait
New-TraceMessage $moduleNameMachineWindows $true
