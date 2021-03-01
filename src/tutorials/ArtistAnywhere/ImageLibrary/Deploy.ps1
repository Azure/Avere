param (
    # Set an Azure resource group naming prefix (with alphanumeric, periods, underscores, hyphens or parenthesis only)
    [string] $resourceGroupNamePrefix = "Artist.Anywhere",

    # Set an Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set an Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share/Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false
)

$rootDirectory = (Get-Item -Path $PSScriptRoot).Parent.FullName

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/ImageLibrary/Deploy.psm1"

$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy
ConvertTo-Json -InputObject $baseFramework | Write-Host

$imageLibrary = Get-ImageLibrary $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName
ConvertTo-Json -InputObject $imageLibrary | Write-Host
