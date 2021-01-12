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

    # Set to the target Azure render manager deployment mode (i.e., OpenCue, VRayDR, CycleCloud or Batch)
    [string] $renderManagerMode = "OpenCue",

    # The Azure shared services framework (e.g., Virtual Network, Managed Identity, Key Vault, etc.)
    [object] $sharedFramework,

    # The Azure storage and cache service resources (e.g., accounts, mounts, etc.)
    [object] $storageCache
)

$rootDirectory = !$PSScriptRoot ? $using:rootDirectory : "$PSScriptRoot/.."
$moduleDirectory = "RenderManager"

Import-Module "$rootDirectory/Deploy.psm1"

# Shared Framework
if (!$sharedFramework) {
    $sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName
}
$computeNetwork = Get-VirtualNetwork $sharedFramework.computeNetworks $computeRegionName
$managedIdentity = $sharedFramework.managedIdentity
$logAnalytics = $sharedFramework.logAnalytics
$imageGallery = $sharedFramework.imageGallery

# Storage Cache
if (!$storageCache) {
    $storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
}
$storageAccount = $storageCache.storageAccounts[0]

# 08 - Batch Account
if ($renderManagerMode -eq "Batch") {
    $moduleName = "08 - Batch Account"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $principalType = "ServicePrincipal"
    $principalId = "f520d84c-3fd3-4cc8-88d4-2ed25b00d27a" # Microsoft Azure Batch
    $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"      # Contributor
    $subscriptionId = az account show --query "id"
    $subscriptionId = "/subscriptions/$subscriptionId"
    $roleAssignment = az role assignment create --role $roleId --scope $subscriptionId --assignee-object-id $principalId --assignee-principal-type $principalType

    $templateFile = "$rootDirectory/$moduleDirectory/08-BatchAccount.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/08-BatchAccount.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $renderManager = $groupDeployment.properties.outputs.renderManager.value
    New-TraceMessage $moduleName $true $computeRegionName
}

# 09 - OpenCue Data
if ($renderManagerMode -eq "CycleCloud" -or $renderManagerMode -eq "OpenCue") {
    $moduleName = "09 - OpenCue Data"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/09-OpenCue.Data.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/09-OpenCue.Data.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 4 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $managerDataServerHost = $groupDeployment.properties.outputs.managerDataServerHost.value
    $managerDataServerPort = $groupDeployment.properties.outputs.managerDataServerPort.value
    $managerDataServerAuth = $groupDeployment.properties.outputs.managerDataServerAuth.value
    New-TraceMessage $moduleName $true $computeRegionName

    # 10.0 - OpenCue Image Template
    $moduleName = "10.0 - OpenCue Image Template"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Gallery"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/10-OpenCue.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value

    if (Confirm-ImageTemplates $resourceGroupName $imageTemplates) {
        $templateFile = "$rootDirectory/$moduleDirectory/10-OpenCue.Image.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/10-OpenCue.Image.Parameters.json"

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

    # 10.1 - OpenCue Image Build
    $moduleName = "10.1 - OpenCue Image Build"
    Build-ImageTemplates $moduleName $computeRegionName $imageGallery $imageTemplates

    # 11 - OpenCue Machine
    $moduleName = "11 - OpenCue Machine"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/11-OpenCue.Machine.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/11-OpenCue.Machine.Parameters.json"

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
}

# 12 - CycleCloud Machine
if ($renderManagerMode -eq "CycleCloud") {
    $moduleName = "12 - CycleCloud Machine"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Manager"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/12-CycleCloud.Machine.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/12-CycleCloud.Machine.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
    $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

    $imageTermsAccept = az vm image terms accept --publisher $templateConfig.parameters.computeManager.value.image.publisher --offer $templateConfig.parameters.computeManager.value.image.offer --plan $templateConfig.parameters.computeManager.value.image.sku

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $eventGridTopicId = $groupDeployment.properties.outputs.eventGridTopicId.value

    $principalType = "ServicePrincipal"

    $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
    $subscriptionId = az account show --query "id"
    $subscriptionId = "/subscriptions/$subscriptionId"
    $roleAssignment = az role assignment create --role $roleId --scope $subscriptionId --assignee-object-id $managedIdentity.principalId --assignee-principal-type $principalType

    $roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
    $roleAssignment = az role assignment create --role $roleId --scope $eventGridTopicId --assignee-object-id $managedIdentity.principalId --assignee-principal-type $principalType

    New-TraceMessage $moduleName $true $computeRegionName
}

Write-Output -InputObject $renderManager -NoEnumerate
