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
    [boolean] $storageCacheDeploy = $false
)

$rootDirectory = "$PSScriptRoot/.."

Import-Module "$rootDirectory/Deploy.psm1"

$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy
ConvertTo-Json -InputObject $baseFramework | Write-Host

$storageCache = Get-StorageCache $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
ConvertTo-Json -InputObject $storageCache | Write-Host
