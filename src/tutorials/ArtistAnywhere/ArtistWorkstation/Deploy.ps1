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

$rootDirectory = "$PSScriptRoot/.."

Import-Module "$rootDirectory/Deploy.psm1"

# Shared Framework
$sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName

# Storage Cache
$storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy

# Artist Workstation Image [Linux] Job
$workstationImageLinuxModuleName = "Artist Workstation Image [Linux] Job"
New-TraceMessage $workstationImageLinuxModuleName $false
$workstationImageLinuxJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

# Artist Workstation Image [Windows] Job
$workstationImageWindowsModuleName = "Artist Workstation Image [Windows] Job"
New-TraceMessage $workstationImageWindowsModuleName $false
$workstationImageWindowsJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

Receive-Job -Job $workstationImageLinuxJob -Wait
New-TraceMessage $workstationImageLinuxModuleName $true

# Artist Workstation Machine [Linux] Job
$workstationMachineLinuxModuleName = "Artist Workstation Machine [Linux] Job"
New-TraceMessage $workstationMachineLinuxModuleName $false
$workstationMachineLinuxJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

Receive-Job -Job $workstationImageWindowsJob -Wait
New-TraceMessage $workstationImageWindowsModuleName $true

# Artist Workstation Machine [Windows] Job
$workstationMachineWindowsModuleName = "Artist Workstation Machine [Windows] Job"
New-TraceMessage $workstationMachineWindowsModuleName $false
$workstationMachineWindowsJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

Receive-Job -Job $workstationMachineLinuxJob -Wait
New-TraceMessage $workstationMachineLinuxModuleName $true

Receive-Job -Job $workstationMachineWindowsJob -Wait
New-TraceMessage $workstationMachineWindowsModuleName $true
