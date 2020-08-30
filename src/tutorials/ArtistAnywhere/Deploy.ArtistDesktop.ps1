param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name for Compute resources (e.g., Image Builder, Virtual Machines, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for Storage resources (e.g., Virtual Network, NetApp Files, Object Storage, etc.)
    [string] $storageRegionName = "EastUS",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false,

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $vnetGatewayEnable = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

$sharedServices = Get-SharedServices $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppEnable $vnetGatewayEnable
if (!$sharedServices.computeNetwork) {
    return
}

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
New-TraceMessage $moduleName $false
$storageCacheJob = Start-Job -FilePath "$templateDirectory/Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $vnetGatewayEnable, $sharedServices

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
New-TraceMessage $moduleName $false
$artistDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $vnetGatewayEnable, $sharedServices
$artistDesktopImages = Receive-Job -Job $artistDesktopImagesJob -Wait
New-TraceMessage $moduleName $true

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
$sharedServices = Receive-Job -Job $storageCacheJob -Wait
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
New-TraceMessage $moduleName $false
$artistDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $vnetGatewayEnable, $sharedServices, $renderManager
$artistDesktopMachines = Receive-Job -Job $artistDesktopMachinesJob -Wait
New-TraceMessage $moduleName $true
