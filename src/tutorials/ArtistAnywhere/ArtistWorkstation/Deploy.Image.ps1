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
        "teradiciLicenseKey" = ""
        "renderManagers" = @()
    },

    # The base Azure services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $baseFramework,

    # The Azure storage and cache resources (e.g., storage account, storage / cache mounts, etc.)
    [object] $storageCache,

    # The Azure image library resources (e.g., Image Gallery, Container Registry, etc.)
    [object] $imageLibrary
)

$rootDirectory = !$PSScriptRoot ? $using:rootDirectory : (Get-Item -Path $PSScriptRoot).Parent.FullName
$moduleDirectory = "ArtistWorkstation"

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"
Import-Module "$rootDirectory/ImageLibrary/Deploy.psm1"

# Base Framework
if (!$baseFramework) {
    $baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy
}
$computeNetwork = $baseFramework.computeNetwork
$managedIdentity = $baseFramework.managedIdentity

# Storage Cache
if (!$storageCache) {
    $storageCache = Get-StorageCache $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageServiceDeploy $storageCacheDeploy
}
$storageAccount = $storageCache.storageAccount

# Image Library
if (!$imageLibrary) {
    $imageLibrary = Get-ImageLibrary $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName
}
$imageGallery = $imageLibrary.imageGallery

# (18.1) Artist Workstation Image Template
$moduleName = "(18.1) Artist Workstation Image Template"
New-TraceMessage $moduleName $false
$resourceGroupNameSuffix = "-Gallery"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$rootDirectory/$moduleDirectory/18-Image.json"
$templateParameters = "$rootDirectory/$moduleDirectory/18-Image.Parameters.json"
$templateConfig = Set-ImageTemplates $imageGallery $templateParameters $artistWorkstation.types

$templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
$templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
$templateConfig.parameters.imageGallery.value.name = $imageGallery.name
$templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
    if ($imageTemplate.deploy) {
        $imageTemplate.buildCustomization = @()
        $scriptFile = "18-Image"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
        $imageTemplate.buildCustomization += $customizeCommand
        if ($renderFarm.managerType.Contains("OpenCue")) {
            $scriptFile = "18-Image.OpenCue"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }
        if ($renderFarm.managerType.Contains("RoyalRender")) {
            $scriptFile = "18-Image.RoyalRender"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }
        if ($artistWorkstation.teradiciLicenseKey -ne "") {
            $scriptFile = "18-Image.Teradici"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }
        $scriptFile = "19-Machine"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate "File" $scriptFile $true
        $imageTemplate.buildCustomization += $customizeCommand
    }
}
$templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
$templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
New-TraceMessage $moduleName $true

# (18.2) Artist Workstation Image Build
$moduleName = "(18.2) Artist Workstation Image Build"
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $templateConfig.parameters.imageTemplates.value
