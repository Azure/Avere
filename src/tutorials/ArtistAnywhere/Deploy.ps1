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
    }
)

$rootDirectory = (Get-Item -Path $PSScriptRoot).FullName
$moduleDirectory = "RenderFarm"

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"
Import-Module "$rootDirectory/ImageLibrary/Deploy.psm1"

# Base Framework
$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy
$computeNetwork = $baseFramework.computeNetwork
$logAnalytics = $baseFramework.logAnalytics
$managedIdentity = $baseFramework.managedIdentity

# Storage Cache
$storageCache = Get-StorageCache $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageServiceDeploy $storageCacheDeploy
$storageAccount = $storageCache.storageAccount
$storageMounts = $storageCache.storageMounts
$cacheMount = $storageCache.cacheMount

# Image Library
$imageLibrary = Get-ImageLibrary $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName
$imageGallery = $imageLibrary.imageGallery

# Render Manager Job
$renderManagerModuleName = "Render Manager Job"
New-TraceMessage $renderManagerModuleName $false
$renderManagerJob = Start-Job -FilePath "$rootDirectory/RenderManager/Deploy.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $renderFarm, $baseFramework, $storageCache, $imageLibrary

# Artist Workstation Image Job
if ($artistWorkstation.types.length -gt 0) {
    $artistWorkstationImageModuleName = "Artist Workstation Image Job"
    New-TraceMessage $artistWorkstationImageModuleName $false
    $artistWorkstationImageJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $renderFarm, $artistWorkstation, $baseFramework, $storageCache, $imageLibrary
}

# (16.1) Render Node Image Template
$moduleName = "(16.1) Render Node Image Template"
New-TraceMessage $moduleName $false
$resourceGroupNameSuffix = "-Gallery"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$rootDirectory/$moduleDirectory/16-NodeImage.json"
$templateParameters = "$rootDirectory/$moduleDirectory/16-NodeImage.Parameters.json"
$templateConfig = Set-ImageTemplates $imageGallery $templateParameters $renderFarm.nodeTypes

$templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
$templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
$templateConfig.parameters.imageGallery.value.name = $imageGallery.name
$templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
    if ($imageTemplate.deploy) {
        $imageTemplate.buildCustomization = @()
        foreach ($storageMount in $storageMounts) {
            $scriptFile = Get-MountUnitFileName $storageMount
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory "StorageCache" $storageAccount $imageGallery $imageTemplate "File" $scriptFile $false
            $imageTemplate.buildCustomization += $customizeCommand
        }
        if ($cacheMount) {
            $scriptFile = Get-MountUnitFileName $cacheMount
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory "StorageCache" $storageAccount $imageGallery $imageTemplate "File" $scriptFile $false
            $imageTemplate.buildCustomization += $customizeCommand
        }

        $scriptFile = "16-NodeImage"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
        $imageTemplate.buildCustomization += $customizeCommand

        $scriptFile = "16-NodeImage.Blender"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
        $imageTemplate.buildCustomization += $customizeCommand

        if ($renderFarm.managerType.Contains("OpenCue")) {
            $scriptFile = "16-NodeImage.OpenCue"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }

        if ($renderFarm.managerType.Contains("RoyalRender")) {
            $scriptFile = "16-NodeImage.RoyalRender"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }

        if (!$renderFarm.managerType.Contains("HPC")) {
            $scriptFile = "17-ScaleSet"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate "File" $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }
    }
}
$templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
$templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
New-TraceMessage $moduleName $true

# (16.2) Render Node Image Build
$moduleName = "(16.2) Render Node Image Build"
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $templateConfig.parameters.imageTemplates.value

# Render Manager Job
$artistWorkstation.renderManagers = Receive-Job -Job $renderManagerJob -Wait
New-TraceMessage $renderManagerModuleName $true

if ($artistWorkstation.types.length -gt 0) {
    Receive-Job -Job $artistWorkstationImageJob -Wait
    New-TraceMessage $artistWorkstationImageModuleName $true

    # Artist Workstation Machine Job
    $artistWorkstationMachineModuleName = "Artist Workstation Machine Job"
    New-TraceMessage $artistWorkstationMachineModuleName $false
    $artistWorkstationMachineJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageServiceDeploy, $storageCacheDeploy, $artistWorkstation, $baseFramework, $storageCache, $imageLibrary
}

# (17) Render Farm Scale Set
if ($renderFarm.managerType -eq "OpenCue" -or $renderFarm.managerType -eq "RoyalRender") {
    $moduleName = "(17) Render Farm Scale Set"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Farm"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/17-ScaleSet.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/17-ScaleSet.Parameters.json"
    $templateConfig = Set-VirtualMachines $imageGallery $templateParameters $renderFarm.nodeTypes

    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName

    $customExtension = $templateConfig.parameters.customExtension.value
    if ($renderManagers.length -gt 0) {
        $customExtension.scriptParameters.renderManagerHost = $renderManagers[0].host
    }

    $scriptFilePath = $customExtension.linux.scriptFilePath
    $scriptParameters = Get-ExtensionParameters $scriptFilePath $customExtension.scriptParameters
    $customExtension.linux.scriptParameters = $scriptParameters

    $scriptFilePath = $customExtension.windows.scriptFilePath
    $scriptParameters = Get-ExtensionParameters $scriptFilePath $customExtension.scriptParameters
    $customExtension.windows.scriptParameters = $scriptParameters

    $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
    $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true
}

if ($artistWorkstation.types.length -gt 0) {
    Receive-Job -Job $artistWorkstationMachineJob -Wait
    New-TraceMessage $artistWorkstationMachineModuleName $true
}
