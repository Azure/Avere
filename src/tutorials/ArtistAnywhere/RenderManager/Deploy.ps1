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

    # Set to the target Azure render manager deployment mode (i.e., OpenCue[.CycleCloud], Deadline[.CycleCloud] or Batch)
    [string] $renderManagerMode = "OpenCue",

    # The base Azure services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $baseFramework,

    # The Azure storage and cache service resources (e.g., accounts, mounts, etc.)
    [object] $storageCache,

    # The Azure render manager operating system type (i.e., Linux or Windows)
    [string] $osType
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

if ($renderManagerMode -ne "Batch") {
    # 10 - Database
    $moduleName = "10 - Database"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/10-Database.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/10-Database.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    if ($renderManagerMode.Contains("OpenCue")) {
        $templateConfig.parameters.postgreSql.value.deploy = $true
    }
    if ($renderManagerMode.Contains("Deadline")) {
        $templateConfig.parameters.mongoDb.value.deploy = $true
    }
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $managerDataServerHost = $groupDeployment.properties.outputs.managerDataServerHost.value
    $managerDataServerPort = $groupDeployment.properties.outputs.managerDataServerPort.value
    $managerDataServerAuth = $groupDeployment.properties.outputs.managerDataServerAuth.value
    New-TraceMessage $moduleName $true $computeRegionName

    # 11.0 - Image Template
    $moduleName = "11.0 - Image Template"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Gallery"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/11-Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
    $deployEnabled = Set-ImageTemplates $resourceGroupName $imageTemplates $osType

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
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

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
    $scriptParameters.DATA_HOST = $managerDataServerHost
    $scriptParameters.DATA_PORT = $managerDataServerPort
    $scriptParameters.ADMIN_AUTH = $managerDataServerAuth
    $fileParameters = Get-ObjectProperties $scriptParameters $false
    $templateConfig.parameters.scriptExtension.value.fileParameters = $fileParameters

    $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
    $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $renderManager = $groupDeployment.properties.outputs.renderManager.value
    $renderManager.host ??= ""
    New-TraceMessage $moduleName $true $computeRegionName

    # 13 - Cycle Cloud
    if ($renderManagerMode.Contains("CycleCloud")) {
        $moduleName = "13 - Cycle Cloud"
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
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

        az vm image terms accept --publisher $templateConfig.parameters.computeManager.value.image.publisher --offer $templateConfig.parameters.computeManager.value.image.offer --plan $templateConfig.parameters.computeManager.value.image.sku

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $eventGridTopicId = $groupDeployment.properties.outputs.eventGridTopicId.value

        $principalType = "ServicePrincipal"

        $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
        $subscriptionId = az account show --query "id"
        Set-RoleAssignment $roleId $managedIdentity.principalId $principalType "/subscriptions/$subscriptionId" $false $false

        $roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
        Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $eventGridTopicId $false $false

        New-TraceMessage $moduleName $true $computeRegionName
    }
} else {
    # 14 - Batch Account
    $moduleName = "14 - Batch Account"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $principalType = "ServicePrincipal"
    $principalId = "f520d84c-3fd3-4cc8-88d4-2ed25b00d27a" # Microsoft Azure Batch
    $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"      # Contributor
    $subscriptionId = az account show --query "id"
    $subscriptionId = "/subscriptions/$subscriptionId"
    Set-RoleAssignment $roleId $principalId $principalType $subscriptionId $false $false

    $templateFile = "$rootDirectory/$moduleDirectory/14-BatchAccount.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/14-BatchAccount.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.keyVault.value.name = $keyVault.name
    $templateConfig.parameters.keyVault.value.resourceGroupName = $keyVault.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $renderManager = $groupDeployment.properties.outputs.renderManager.value
    New-TraceMessage $moduleName $true $computeRegionName
}

New-TraceMessage $moduleGroupName $true
Write-Output -InputObject $renderManager -NoEnumerate
