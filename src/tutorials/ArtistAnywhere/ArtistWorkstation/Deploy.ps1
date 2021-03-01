param (
    # Set an Azure resource group naming prefix (with alphanumeric, periods, underscores, hyphens or parenthesis only)
    [string] $resourceGroupNamePrefix = "Artist.Anywhere",

    # Set an Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set an Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share/Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to optionally deploy an Azure 1st-party and/or 3rd-party storage service in the Azure storage region
    [object] $storageServiceDeploy = @{
        "netAppFiles" = $false # https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction
        "hammerspace" = $false
        "qumulo" = $false
    },

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) service
    [boolean] $storageCacheDeploy = $false,

    # Set the target Azure render farm deployment model, which defines the machine image customization process
    [object] $renderFarm = @{
        "managerType" = "OpenCue" # OpenCue[.HPC] or RoyalRender[.HPC]
        "nodeTypes" = @("Linux", "Windows")
    },

    # Set the Azure artist workstation deployment model, which defines the machine image customization process
    [object] $artistWorkstation = @{
        "types" = @("Linux", "Windows")
    },

    # The optional Teradici host agent license key. If the key is blank, Teradici deployment is skipped
    [string] $teradiciLicenseKey = "",

    # The Azure render managers for job submission from an artist workstation content creation app
    [object[]] $renderManagers = @()
)

$rootDirectory = (Get-Item -Path $PSScriptRoot).Parent.FullName

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"
Import-Module "$rootDirectory/ImageLibrary/Deploy.psm1"

# Base Framework
$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy

# Storage Cache
$storageCache = Get-StorageCache $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageServiceDeploy $storageCacheDeploy

# Image Library
$imageLibrary = Get-ImageLibrary $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName

# Artist Workstation Image Job
$moduleName = "Artist Workstation Image Job"
New-TraceMessage $moduleName $false
$imageJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $renderFarm, $artistWorkstation, $teradiciLicenseKey, $baseFramework, $storageCache, $imageLibrary
Receive-Job -Job $imageJob -Wait
New-TraceMessage $moduleName $true

# Artist Workstation Machine Job
$moduleName = "Artist Workstation Machine Job"
New-TraceMessage $moduleName $false
$machineJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $artistWorkstation, $teradiciLicenseKey, $renderManagerHost, $baseFramework, $storageCache, $imageLibrary
Receive-Job -Job $machineJob -Wait
New-TraceMessage $moduleName $true
