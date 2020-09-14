param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name for Compute resources (e.g., Shared Image Gallery, Container Registry, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for Storage resources (e.g., Virtual Network, NetApp Files, Object Storage, etc.)
    [string] $storageRegionName = "EastUS",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $vnetGatewayEnable = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

$sharedServices = Get-SharedServices $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppEnable $vnetGatewayEnable

Write-Output -InputObject $sharedServices -NoEnumerate
