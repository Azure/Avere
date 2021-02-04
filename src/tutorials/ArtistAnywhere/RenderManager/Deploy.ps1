param (
    # Set a name prefix for the Azure resource groups that are created by this automated deployment script
    [string] $resourceGroupNamePrefix = "ArtistAnywhere",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share / Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway services (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) in the compute region
    [boolean] $storageCacheDeploy = $false,

    # Set to the target Azure render management deployment mode (i.e., OpenCue[.CycleCloud], Deadline[.CycleCloud] or Batch)
    [string] $renderManagerMode = "OpenCue",

    # Set the operating system type (i.e., Linux or Windows) for the Azure render manager/node images and virtual machines
    [string] $renderFarmType = "Linux",

    # The base Azure services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $baseFramework,

    # The Azure storage and cache service resources (e.g., storage account, cache mount, etc.)
    [object] $storageCache
)

$rootDirectory = !$PSScriptRoot ? $using:rootDirectory : "$PSScriptRoot/.."
$moduleDirectory = "RenderManager"

Import-Module "$rootDirectory/Deploy.psm1"

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
    $storageCache = Get-StorageCache $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
}
$storageAccount = $storageCache.storageAccount

$moduleGroupName = "Render Manager"
New-TraceMessage $moduleGroupName $false

if ($renderManagerMode -eq "Batch") {
    Set-RoleAssignments "Batch" $null $computeNetwork $managedIdentity $keyVault $imageGallery

    # 14 - Batch Account
    $moduleName = "14 - Batch Account"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/14-BatchAccount.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/14-BatchAccount.Parameters.json"

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
    New-TraceMessage $moduleName $true $computeRegionName
} else {
    # 10 - Database
    $moduleName = "10 - Database"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/10-Database.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/10-Database.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.postgreSql.value.deploy = $renderManagerMode.Contains("OpenCue")
    $templateConfig.parameters.mongoDb.value.deploy = $renderManagerMode.Contains("Deadline")
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
    New-TraceMessage $moduleName $true $computeRegionName

    # 11.0 - Image Template
    $moduleName = "11.0 - Image Template"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Gallery"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/11-Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
    $deployEnabled = Set-ImageTemplates $resourceGroupName $imageTemplates $renderFarmType

    if ($deployEnabled) {
        $templateFile = "$rootDirectory/$moduleDirectory/11-Image.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/11-Image.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
        $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
        $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
        $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
        $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    }
    New-TraceMessage $moduleName $true $computeRegionName

    # 11.1 - Image Build
    $moduleName = "11.1 - Image Build"
    Build-ImageTemplates $moduleName $computeRegionName $imageGallery $imageTemplates

    # 12 - Machine
    $moduleName = "12 - Machine"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/12-Machine.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/12-Machine.Parameters.json"

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
    New-TraceMessage $moduleName $true $computeRegionName

    # 13 - CycleCloud
    if ($renderManagerMode.Contains("CycleCloud")) {
        $moduleName = "13 - CycleCloud"
        New-TraceMessage $moduleName $false $computeRegionName
        $resourceGroupNameSuffix = ".Manager"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/13-CycleCloud.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/13-CycleCloud.Parameters.json"

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
        New-TraceMessage $moduleName $true $computeRegionName

        Set-RoleAssignments "CycleCloud" $null $computeNetwork $managedIdentity $keyVault $imageGallery $eventGridTopicId
    }
}

New-TraceMessage $moduleGroupName $true
Write-Output -InputObject $renderManager -NoEnumerate
