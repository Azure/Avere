param (
    # Set a name prefix for the Azure resource groups that are created by this resource deployment script
    [string] $resourceGroupNamePrefix = "Azure.Artist.Anywhere",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share/Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to deploy one or more Azure 1st-party and/or 3rd-party storage services within the Azure storage region
    [object] $storageServiceDeploy = @{
        "blobStorage" = $false  # https://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview
        "netAppFiles" = $false  # https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction
        "hammerspace" = $false
        "qumulo" = $false
    },

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) service
    [boolean] $storageCacheDeploy = $false,

    # Set to the target Azure render manager deployment mode (i.e., OpenCue[.HPC], RoyalRender[.HPC] or Batch)
    [string] $renderManagerMode = "OpenCue",

    # Set the operating system types for the Azure render manager/node image builds and virtual machines
    [string[]] $renderFarmTypes = @("Linux", "Windows"),

    # The base Azure services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $baseFramework,

    # The Azure storage and cache service resources (e.g., storage account, cache mount, etc.)
    [object] $storageCache
)

$rootDirectory = !$PSScriptRoot ? $using:rootDirectory : (Get-Item -Path $PSScriptRoot).Parent.FullName
$moduleDirectory = "RenderManager"

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"

# Base Framework
if (!$baseFramework) {
    $baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName
}
$computeNetwork = $baseFramework.computeNetwork
$managedIdentity = $baseFramework.managedIdentity
$keyVault = $baseFramework.keyVault
$logAnalytics = $baseFramework.logAnalytics
$imageGallery = $baseFramework.imageGallery

# Storage Cache
if (!$storageCache) {
    $storageCache = Get-StorageCache $rootDirectory $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageServiceDeploy $storageCacheDeploy
}
$storageAccount = $storageCache.storageAccount

if ($renderManagerMode -eq "Batch") {
    Set-RoleAssignments "Batch" $null $computeNetwork $managedIdentity $keyVault $imageGallery

    # (17) Render Manager Batch Account
    $moduleName = "(17) Render Manager Batch Account"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Manager.Compute"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/17-BatchAccount.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/17-BatchAccount.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.keyVault.value.name = $keyVault.name
    $templateConfig.parameters.keyVault.value.resourceGroupName = $keyVault.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $renderManager = $groupDeployment.properties.outputs.renderManager.value
    New-TraceMessage $moduleName $true
} else {
    # (13) Render Manager Database
    $moduleName = "(13) Render Manager Database"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Manager.Data"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/13-Database.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/13-Database.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.postgreSql.value.deploy = $renderManagerMode.Contains("OpenCue")
    $templateConfig.parameters.mongoDb.value.deploy = $renderManagerMode.Contains("OpenCue")
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $postgreSqlHost = $groupDeployment.properties.outputs.postgreSqlHost.value
    $postgreSqlPort = $groupDeployment.properties.outputs.postgreSqlPort.value
    $postgreSqlAdminUsername = $groupDeployment.properties.outputs.postgreSqlAdminUsername.value
    $postgreSqlAdminPassword = $groupDeployment.properties.outputs.postgreSqlAdminPassword.value
    $mongoDbHost = $groupDeployment.properties.outputs.mongoDbHost.value
    $mongoDbPort = $groupDeployment.properties.outputs.mongoDbPort.value
    $mongoDbAdminUsername = $groupDeployment.properties.outputs.mongoDbAdminUsername.value
    $mongoDbAdminPassword = $groupDeployment.properties.outputs.mongoDbAdminPassword.value
    New-TraceMessage $moduleName $true

    # (14.1) Render Manager Image Template
    $moduleName = "(14.1) Render Manager Image Template [" + ($renderFarmTypes -join ",") + "]"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Gallery"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/14-Image.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/14-Image.Parameters.json"
    $templateConfig = Set-ImageTemplates $resourceGroupName $templateParameters $renderFarmTypes

    foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
        if ($imageTemplate.deploy) {
            $imageTemplate.buildCustomization = @()
            if ($renderManagerMode.Contains("OpenCue")) {
                $scriptFile = "14-Image.OpenCue"
                $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
                $imageTemplate.buildCustomization += $customizeCommand
            }
            if ($renderManagerMode.Contains("RoyalRender")) {
                $scriptFile = "14-Image.RoyalRender"
                $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
                $imageTemplate.buildCustomization += $customizeCommand
            }
            $scriptFile = "15-Machine"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageTemplate.imageOperatingSystemType $scriptFile
            $imageTemplate.buildCustomization += $customizeCommand
        }
    }

    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true

    # (14.2) Render Manager Image Build
    $moduleName = "(14.2) Render Manager Image Build [" + ($renderFarmTypes -join ",") + "]"
    Build-ImageTemplates $moduleName $computeRegionName $imageGallery $templateConfig.parameters.imageTemplates.value

    # (15) Render Manager Machine
    $moduleName = "(15) Render Manager Machine [" + ($renderFarmTypes -join ",") + "]"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Manager.Compute"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/15-Machine.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/15-Machine.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName

    $scriptParameters = $templateConfig.parameters.scriptExtension.value.scriptParameters
    $scriptParameters.postgreSqlHost = $postgreSqlHost
    $scriptParameters.postgreSqlPort = $postgreSqlPort
    $scriptParameters.postgreSqlAdminUsername = $postgreSqlAdminUsername
    $scriptParameters.postgreSqlAdminPassword = $postgreSqlAdminPassword
    $scriptParameters.mongoDbHost = $mongoDbHost
    $scriptParameters.mongoDbPort = $mongoDbPort
    $scriptParameters.mongoDbAdminUsername = $mongoDbAdminUsername
    $scriptParameters.mongoDbAdminPassword = $mongoDbAdminPassword
    $fileParameters = Get-ObjectProperties $scriptParameters $false
    $templateConfig.parameters.scriptExtension.value.fileParameters = $fileParameters

    $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
    $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $renderManager = $groupDeployment.properties.outputs.renderManager.value
    $renderManager.host ??= ""
    New-TraceMessage $moduleName $true

    # (16) Render Manager CycleCloud
    if ($renderManagerMode.Contains("HPC")) {
        $moduleName = "(16) Render Manager CycleCloud"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Manager.Compute"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/16-CycleCloud.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/16-CycleCloud.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
        $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
        $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
        $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
        $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        az vm image terms accept --publisher $templateConfig.parameters.computeManager.value.image.publisher --offer $templateConfig.parameters.computeManager.value.image.offer --plan $templateConfig.parameters.computeManager.value.image.sku

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $eventGridTopicId = $groupDeployment.properties.outputs.eventGridTopicId.value
        New-TraceMessage $moduleName $true

        Set-RoleAssignments "CycleCloud" $null $computeNetwork $managedIdentity $keyVault $imageGallery $eventGridTopicId
    }
}

Write-Output -InputObject $renderManager -NoEnumerate
