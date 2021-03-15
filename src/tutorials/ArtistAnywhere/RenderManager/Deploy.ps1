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
        "hammerspace" = $false # TBD
        "qumulo" = $false      # TBD
    },

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) service
    [boolean] $storageCacheDeploy = $false,

    # Set the target Azure render farm deployment model, which defines the machine image customization process
    [object] $renderFarm = @{
        "managerType" = "OpenCue" # OpenCue[.HPC] or RoyalRender[.HPC]
        "nodeTypes" = @("Linux")
    },

    # The base Azure services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $baseFramework,

    # The Azure storage and cache resources (e.g., storage account, storage / cache mounts, etc.)
    [object] $storageCache,

    # The Azure image library resources (e.g., Image Gallery, Container Registry, etc.)
    [object] $imageLibrary
)

$rootDirectory = !$PSScriptRoot ? $using:rootDirectory : (Get-Item -Path $PSScriptRoot).Parent.FullName
$moduleDirectory = "RenderManager"

Import-Module "$rootDirectory/Deploy.psm1"
Import-Module "$rootDirectory/BaseFramework/Deploy.psm1"
Import-Module "$rootDirectory/StorageCache/Deploy.psm1"
Import-Module "$rootDirectory/ImageLibrary/Deploy.psm1"

# Base Framework
if (!$baseFramework) {
    $baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName
}
$computeNetwork = $baseFramework.computeNetwork
$logAnalytics = $baseFramework.logAnalytics
$managedIdentity = $baseFramework.managedIdentity
$keyVault = $baseFramework.keyVault

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

# (12) Render Manager Database
$moduleName = "(12) Render Manager Database"
New-TraceMessage $moduleName $false
$resourceGroupNameSuffix = "-Manager.Data"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$rootDirectory/$moduleDirectory/12-Database.json"
$templateParameters = "$rootDirectory/$moduleDirectory/12-Database.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.postgreSql.value.deploy = $renderFarm.managerType.Contains("OpenCue")
$templateConfig.parameters.mongoDb.value.deploy = $false
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

# (13.1) Render Manager Image Template
$moduleName = "(13.1) Render Manager Image Template"
New-TraceMessage $moduleName $false
$resourceGroupNameSuffix = "-Gallery"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$rootDirectory/$moduleDirectory/13-Image.json"
$templateParameters = "$rootDirectory/$moduleDirectory/13-Image.Parameters.json"
$templateConfig = Set-ImageTemplates $imageGallery $templateParameters $renderFarm.nodeTypes

$templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
$templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
$templateConfig.parameters.imageGallery.value.name = $imageGallery.name
$templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
    if ($imageTemplate.deploy) {
        $imageTemplate.buildCustomization = @()
        if ($renderFarm.managerType.Contains("OpenCue")) {
            $scriptFile = "13-Image.OpenCue"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }
        if ($renderFarm.managerType.Contains("RoyalRender")) {
            $scriptFile = "13-Image.RoyalRender"
            $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate $null $scriptFile $true
            $imageTemplate.buildCustomization += $customizeCommand
        }
        $scriptFile = "14-Machine"
        $customizeCommand = Get-ImageCustomizeCommand $rootDirectory $moduleDirectory $storageAccount $imageGallery $imageTemplate "File" $scriptFile $true
        $imageTemplate.buildCustomization += $customizeCommand
    }
}
$templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
$templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
$templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
New-TraceMessage $moduleName $true

# (13.2) Render Manager Image Build
$moduleName = "(13.2) Render Manager Image Build"
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $templateConfig.parameters.imageTemplates.value

# (14) Render Manager Machine
$moduleName = "(14) Render Manager Machine"
New-TraceMessage $moduleName $false
$resourceGroupNameSuffix = "-Manager.Compute"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$templateFile = "$rootDirectory/$moduleDirectory/14-Machine.json"
$templateParameters = "$rootDirectory/$moduleDirectory/14-Machine.Parameters.json"
$templateConfig = Set-VirtualMachines $imageGallery $templateParameters $renderFarm.nodeTypes

$templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
$templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
$templateConfig.parameters.imageGallery.value.name = $imageGallery.name
$templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName

$customExtension = $templateConfig.parameters.customExtension.value
$customExtension.scriptParameters.dataTierHost = $postgreSqlHost
$customExtension.scriptParameters.dataTierPort = $postgreSqlPort
$customExtension.scriptParameters.adminUsername = $postgreSqlAdminUsername
$customExtension.scriptParameters.adminPassword = $postgreSqlAdminPassword

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

$renderManagers = $groupDeployment.properties.outputs.renderManagers.value
New-TraceMessage $moduleName $true

# (15) Render Manager CycleCloud
if ($renderFarm.managerType.Contains("HPC")) {
    $moduleName = "(15) Render Manager CycleCloud"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Manager.Compute"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/15-CycleCloud.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/15-CycleCloud.Parameters.json"

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

Write-Output -InputObject $renderManagers -NoEnumerate
