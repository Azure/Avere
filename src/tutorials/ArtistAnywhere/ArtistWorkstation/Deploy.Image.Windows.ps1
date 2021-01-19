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
    [boolean] $storageCacheDeploy = $false,

    # The Azure shared services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $sharedFramework,

    # The Azure storage and cache service resources (e.g., accounts, mounts, etc.)
    [object] $storageCache
)

$rootDirectory = !$PSScriptRoot ? $using:rootDirectory : "$PSScriptRoot/.."
$moduleDirectory = "ArtistWorkstation"

Import-Module "$rootDirectory/Deploy.psm1"

# Shared Framework
if (!$sharedFramework) {
    $sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName
}
$computeNetwork = Get-VirtualNetwork $sharedFramework.computeNetworks $computeRegionName
$managedIdentity = $sharedFramework.managedIdentity
$imageGallery = $sharedFramework.imageGallery

# Storage Cache
if (!$storageCache) {
    $storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
}

# 15.2 - Artist Workstation Image Templates [Windows]
$moduleName = "15.2 - Artist Workstation Image Templates [Windows]"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupNameSuffix = ".Gallery"
$resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/15-Windows.Workstation.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value

if (Confirm-ImageTemplates $resourceGroupName $imageTemplates) {
    $templateFile = "$rootDirectory/$moduleDirectory/15-Windows.Workstation.Image.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/15-Windows.Workstation.Image.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
}
New-TraceMessage $moduleName $true $computeRegionName

# 15.3 - Artist Workstation Image Build [Windows]
$moduleName = "15.3 - Artist Workstation Image Build [Windows]"
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $imageTemplates
