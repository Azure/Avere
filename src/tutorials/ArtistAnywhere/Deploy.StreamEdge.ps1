param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Pipeline",

    # Set the Azure region name for shared resources (e.g., Managed Identity, Key Vault, Monitor Insight, etc.)
    [string] $sharedRegionName = "WestUS2",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machines, Batch Accounts, etc.)
    [string] $computeRegionName = "EastUS",

    # Set the Azure region name for storage cache resources (e.g., HPC Cache, Storage Targets, Namespace Paths, etc.)
    [string] $cacheRegionName = "",

    # Set the Azure region name for storage resources (e.g., Storage Accounts, File Shares, Object Containers, etc.)
    [string] $storageRegionName = "EastUS",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false,

    # The Azure shared services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $sharedFramework,

    # The Azure storage and cache service resources (e.g., accounts, mounts, etc.)
    [object] $storageCache
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# Shared Framework
if (!$sharedFramework) {
    $sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName
}

# Storage Cache
if (!$storageCache) {
    $storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $cacheRegionName $storageRegionName $storageNetAppDeploy
}
$storageAccount = $storageCache.storageAccounts[0]

$moduleDirectory = "StreamEdge"

# 17 - Remote Render
$moduleName = "17 - Remote Render"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupNameSuffix = ".Stream"
$resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/17-RemoteRender.json"
$templateParameters = "$templateDirectory/$moduleDirectory/17-RemoteRender.Parameters.json"

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
$renderAccount = $groupDeployment.properties.outputs.renderAccount.value
New-TraceMessage $moduleName $true $computeRegionName

# 18 - Media Services
$moduleName = "18 - Media Services"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupNameSuffix = ".Stream"
$resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/18-MediaServices.json"
$templateParameters = "$templateDirectory/$moduleDirectory/18-MediaServices.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.storageAccount.value.name = $storageAccount.name
$templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
$templateConfig | ConvertTo-Json -Depth 3 | Out-File $templateParameters

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
$mediaAccount = $groupDeployment.properties.outputs.mediaAccount.value
New-TraceMessage $moduleName $true $computeRegionName
