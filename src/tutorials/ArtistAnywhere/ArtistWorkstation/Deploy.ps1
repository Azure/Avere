param (
    # Set a name prefix for the Azure resource groups that are created by this resource deployment script
    [string] $resourceGroupNamePrefix = "Azure.Artist.Anywhere",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share/Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to deploy one or more Azure 1st-party and/or 3rd-party storage services within the Azure storage region
    [object] $storageServiceDeploy = @{
        "blobStorage" = $false  # https://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview
        "netAppFiles" = $false  # https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction
        "hammerspace" = $false
        "qumulo" = $false
    },

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) service
    [boolean] $storageCacheDeploy = $false,

    # Set the operating system types for the Azure artist workstation image builds and virtual machines
    [string[]] $artistWorkstationTypes = @("Linux", "Windows")
)

$rootDirectory = (Get-Item -Path $PSScriptRoot).Parent.FullName

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"

# Base Framework
$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy

# Storage Cache
$storageCache = Get-StorageCache $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageServiceDeploy $storageCacheDeploy

# Artist Workstation Image Job
$moduleName = "Artist Workstation Image Job"
New-TraceMessage $moduleName $false
$imageJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $baseFramework, $storageCache, $artistWorkstationTypes
Receive-Job -Job $imageJob -Wait
New-TraceMessage $moduleName $true

# Artist Workstation Machine Job
$moduleName = "Artist Workstation Machine Job"
New-TraceMessage $moduleName $false
$machineJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $baseFramework, $storageCache, $artistWorkstationTypes
Receive-Job -Job $machineJob -Wait
New-TraceMessage $moduleName $true
