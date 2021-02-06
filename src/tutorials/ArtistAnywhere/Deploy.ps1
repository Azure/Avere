param (
    # Set a name prefix for the Azure resource groups that are created by this resource deployment script
    [string] $resourceGroupNamePrefix = "Azure.Artist.Anywhere",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share/Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) in the compute region
    [boolean] $storageCacheDeploy = $false,

    # Set to the target Azure render manager deployment mode (i.e., OpenCue[.HPC], RoyalRender[.HPC] or Batch)
    [string] $renderManagerMode = "OpenCue",

    # Set the operating system types for the Azure render manager/node image builds and virtual machines
    [string[]] $renderFarmTypes = @("Linux", "Windows"),

    # Set the operating system types for the Azure artist workstation image builds and virtual machines
    [string[]] $artistWorkstationTypes = @()
)

$rootDirectory = (Get-Item -Path $PSScriptRoot).FullName
$moduleDirectory = "RenderFarm"

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"

# Base Framework
$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy
$computeNetwork = $baseFramework.computeNetwork
$managedIdentity = $baseFramework.managedIdentity
$logAnalytics = $baseFramework.logAnalytics
$imageGallery = $baseFramework.imageGallery
$containerRegistry = $baseFramework.containerRegistry

# Storage Cache
$storageCache = Get-StorageCache $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
$storageAccount = $storageCache.storageAccount
$storageMounts = $storageCache.storageMounts
$cacheMount = $storageCache.cacheMount

# Render Manager Job
$renderManagerModuleName = "Render Manager Job"
New-TraceMessage $renderManagerModuleName $false
$renderManagerJob = Start-Job -FilePath "$rootDirectory/RenderManager/Deploy.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageNetAppDeploy, $storageCacheDeploy, $renderManagerMode, $renderFarmTypes, $baseFramework, $storageCache

# Artist Workstation Image Job
if ($artistWorkstationTypes.length -gt 0) {
    $artistWorkstationImageModuleName = "Artist Workstation Image Job"
    New-TraceMessage $artistWorkstationImageModuleName $false
    $artistWorkstationImageJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageNetAppDeploy, $storageCacheDeploy, $artistWorkstationTypes, $baseFramework, $storageCache
}

# (18.1) Render Node Image Template
$moduleName = "(18.1) Render Node Image Template"
New-TraceMessage $moduleName $false
$resourceGroupNameSuffix = "-Gallery"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$rootDirectory/$moduleDirectory/18-Node.Image.json"
$templateParameters = "$rootDirectory/$moduleDirectory/18-Node.Image.Parameters.json"
$templateConfig = Set-ImageTemplates $resourceGroupName $templateParameters $renderFarmTypes

$templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
$templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
$templateConfig.parameters.imageGallery.value.name = $imageGallery.name
$templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
    $imageTemplate.buildCustomization = @()
    foreach ($storageMount in $storageMounts) {
        $scriptFile = Get-MountUnitFileName $storageMount
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory "StorageCache" $storageAccount $null $scriptFile
        $imageTemplate.buildCustomization += $customizeCommand
    }
    if ($cacheMount) {
        $scriptFile = Get-MountUnitFileName $cacheMount
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory "StorageCache" $storageAccount $null $scriptFile
        $imageTemplate.buildCustomization += $customizeCommand
    }

    $scriptFile = "18-Node.Image"
    $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
    $imageTemplate.buildCustomization += $customizeCommand

    $scriptFile = "18-Node.Image.Blender"
    $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
    $imageTemplate.buildCustomization += $customizeCommand

    if ($renderManagerMode.Contains("OpenCue")) {
        $scriptFile = "18-Node.Image.OpenCue"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
        $imageTemplate.buildCustomization += $customizeCommand
    }

    if ($renderManagerMode.Contains("RoyalRender")) {
        $scriptFile = "18-Node.Image.RoyalRender"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
        $imageTemplate.buildCustomization += $customizeCommand
    }

    if (!$renderManagerMode.Contains("HPC") -and $renderManagerMode -ne "Batch") {
        $scriptFile = "19-Farm.ScaleSet"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
        $imageTemplate.buildCustomization += $customizeCommand
    }
}
$templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
$templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
New-TraceMessage $moduleName $true

# (18.2) Render Node Image Build
$moduleName = "(18.2) Render Node Image Build"
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $templateConfig.parameters.imageTemplates.value

# Render Manager Job
$renderManager = Receive-Job -Job $renderManagerJob -Wait
New-TraceMessage $renderManagerModuleName $true

Receive-Job -Job $artistWorkstationImageJob -Wait
New-TraceMessage $artistWorkstationImageModuleName $true

# Artist Workstation Machine Job
if ($artistWorkstationTypes.length -gt 0) {
    $artistWorkstationMachineModuleName = "Artist Workstation Machine Job"
    New-TraceMessage $artistWorkstationMachineModuleName $false
    $artistWorkstationMachineJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy, $storageNetAppDeploy, $storageCacheDeploy, $baseFramework, $storageCache, $artistWorkstationTypes, $renderManager
}

# (19) Farm Pool
if ($renderManagerMode -eq "Batch") {
    $moduleName = "(19) Farm Pool"
    New-TraceMessage $moduleName $false

    $templateFile = "$rootDirectory/$moduleDirectory/19-Farm.Pool.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/19-Farm.Pool.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    $templateConfig.parameters.containerRegistry.value.name = $containerRegistry.name
    $templateConfig.parameters.containerRegistry.value.resourceGroupName = $containerRegistry.resourceGroupName
    $templateConfig.parameters.containerRegistry.value.loginEndpoint = $containerRegistry.loginEndpoint
    $templateConfig.parameters.containerRegistry.value.loginPassword = $containerRegistry.loginPassword
    $templateConfig.parameters.renderManager.value.name = $renderManager.name
    $templateConfig.parameters.renderManager.value.resourceGroupName = $renderManager.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $renderManager.resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true
}

# (19) Farm Scale Set
if ($renderManagerMode -eq "OpenCue" -or $renderManagerMode -eq "RoyalRender") {
    $moduleName = "(19) Farm Scale Set"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Farm"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/19-Farm.ScaleSet.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/19-Farm.ScaleSet.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName

    foreach ($renderFarm in $templateConfig.parameters.renderFarms.value) {
        $scriptParameters = $renderFarm.customExtension.scriptParameters
        if ($renderFarm.image.osType -eq "Windows") {
            $scriptParameters.renderManagerHost = $renderManager.host ?? ""
            $fileParameters = Get-ObjectProperties $scriptParameters $true
        } else {
            $scriptParameters.RENDER_MANAGER_HOST = $renderManager.host ?? ""
            $fileParameters = Get-ObjectProperties $scriptParameters $false
        }
        $renderFarm.customExtension.fileParameters = $fileParameters
    }

    $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
    $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true
}

if ($artistWorkstationTypes.length -gt 0) {
    Receive-Job -Job $artistWorkstationMachineJob -Wait
    New-TraceMessage $artistWorkstationMachineModuleName $true
}
