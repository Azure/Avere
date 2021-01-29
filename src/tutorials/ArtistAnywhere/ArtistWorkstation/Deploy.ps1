param (
    # Set a name prefix for the Azure resource groups that are created by this automated deployment script
    [string] $resourceGroupNamePrefix = "ArtistAnywhere",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share / Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway services (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) in the compute region
    [boolean] $storageCacheDeploy = $false,

    # Set the operating system type (i.e., Linux or Windows) for the Azure artist workstation image and virtual machines
    [string] $artistWorkstationType = "Linux"
)

$rootDirectory = "$PSScriptRoot/.."

Import-Module "$rootDirectory/Deploy.psm1"

# Base Framework
$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy

# Storage Cache
$storageCache = Get-StorageCache $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy

# Artist Workstation Image Job
$moduleName = "Artist Workstation Image [$artistWorkstationType] Job"
New-TraceMessage $moduleName $false
$workstationImageJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageNetAppDeploy, $storageCacheDeploy, $baseFramework, $storageCache, $artistWorkstationType
Receive-Job -Job $workstationImageJob -Wait
New-TraceMessage $moduleName $true

# Artist Workstation Machine Job
$moduleName = "Artist Workstation Machine [$artistWorkstationType] Job"
New-TraceMessage $moduleName $false
$workstationMachineJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageNetAppDeploy, $storageCacheDeploy, $baseFramework, $storageCache, $artistWorkstationType
Receive-Job -Job $workstationMachineJob -Wait
New-TraceMessage $moduleName $true
