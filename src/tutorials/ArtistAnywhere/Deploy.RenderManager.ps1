param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name for Compute resources (e.g., Image Builder, Virtual Machines, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for Storage resources (e.g., Virtual Network, Object (Blob) Storage, NetApp Files, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false,

    # The shared Azure solution services (e.g., Virtual Networks, Managed Identity, Log Analytics, etc.)
    [object] $sharedServices
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
    $templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
if (!$sharedServices) {
    $moduleName = "* - Shared Services Job"
    New-TraceMessage $moduleName $false
    $sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName
    $sharedServices = Receive-Job -Job $sharedServicesJob -Wait
    New-TraceMessage $moduleName $true
}
$computeNetwork = $sharedServices.computeNetwork
$userIdentity = $sharedServices.userIdentity
$logAnalytics = $sharedServices.logAnalytics
$imageGallery = $sharedServices.imageGallery

$moduleDirectory = "RenderManager"

# 06 - Manager Data
$moduleName = "06 - Manager Data"
$resourceGroupNameSuffix = ".Manager"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/06-Manager.Data.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/06-Manager.Data.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetwork.name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 3).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$managerDatabaseSql = $groupDeployment.properties.outputs.managerDatabaseSql.value
$managerDatabaseUrl = $groupDeployment.properties.outputs.managerDatabaseUrl.value
$managerDatabaseName = $groupDeployment.properties.outputs.managerDatabaseName.value
$managerDatabaseUserName = $groupDeployment.properties.outputs.managerDatabaseUserName.value
$managerDatabaseUserLogin = $groupDeployment.properties.outputs.managerDatabaseUserLogin.value
New-TraceMessage $moduleName $true $computeRegionName

# 07.0 - Manager Image Template
$moduleName = "07.0 - Manager Image Template"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/07-Manager.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/07-Manager.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.userIdentity.value.resourceId -eq "") {
    $templateParameters.userIdentity.value.resourceId = $userIdentity.resourceId
}
if ($templateParameters.imageGallery.value.name -eq "") {
    $templateParameters.imageGallery.value.name = $imageGallery.name
}
if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetwork.name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 7).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

New-TraceMessage $moduleName $true $computeRegionName

# 07.1 - Manager Image Version
$moduleName = "07.1 - Manager Image Version"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/07-Manager.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($imageTemplate in $templateParameters.imageTemplates.value) {
    if ($imageTemplate.enabled) {
        New-TraceMessage "$moduleName [$($imageTemplate.templateName)]" $false $computeRegionName
        $imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $imageTemplate.definitionName $imageTemplate.templateName
        if (!$imageVersionId) {
            az image builder run --resource-group $resourceGroupName --name $imageTemplate.templateName
        }
        New-TraceMessage "$moduleName [$($imageTemplate.templateName)]" $true $computeRegionName
    }
}
New-TraceMessage $moduleName $true $computeRegionName

# 08 - Manager Machines
$moduleName = "08 - Manager Machines"
$resourceGroupNameSuffix = ".Manager"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/08-Manager.Machines.json"
$templateParameters = Get-Content "$templateDirectory/$moduleDirectory/08-Manager.Machines.Parameters.json" -Raw | ConvertFrom-Json
$scriptCommands = Get-ScriptCommands "$templateDirectory/$moduleDirectory/08-Manager.Machines.sh"

if ($templateParameters.parameters.userIdentity.value.clientId -eq "") {
    $templateParameters.parameters.userIdentity.value.clientId = $userIdentity.clientId
}
if ($templateParameters.parameters.userIdentity.value.resourceId -eq "") {
    $templateParameters.parameters.userIdentity.value.resourceId = $userIdentity.resourceId
}
if ($templateParameters.parameters.renderManager.value.image.referenceId -eq "") {
    $imageTemplateName = $templateParameters.parameters.renderManager.value.image.templateName
    $imageDefinitionName = $templateParameters.parameters.renderManager.value.image.definitionName
    $imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
    $templateParameters.parameters.renderManager.value.image.referenceId = $imageVersionId
}
if ($templateParameters.parameters.renderManager.value.scriptCommands -eq "") {
    $templateParameters.parameters.renderManager.value.scriptCommands = $scriptCommands
}
if ($templateParameters.parameters.renderManager.value.databaseSql -eq "") {
    $templateParameters.parameters.renderManager.value.databaseSql = $managerDatabaseSql
}
if ($templateParameters.parameters.renderManager.value.databaseUrl -eq "") {
    $templateParameters.parameters.renderManager.value.databaseUrl = $managerDatabaseUrl
}
if ($templateParameters.parameters.renderManager.value.databaseName -eq "") {
    $templateParameters.parameters.renderManager.value.databaseName = $managerDatabaseName
}
if ($templateParameters.parameters.renderManager.value.databaseUserName -eq "") {
    $templateParameters.parameters.renderManager.value.databaseUserName = $managerDatabaseUserName
}
if ($templateParameters.parameters.renderManager.value.databaseUserLogin -eq "") {
    $templateParameters.parameters.renderManager.value.databaseUserLogin = $managerDatabaseUserLogin
}
# if ($templateParameters.parameters.logAnalytics.value.workspaceId -eq "") {
#     $templateParameters.parameters.logAnalytics.value.workspaceId = $logAnalytics.workspaceId
# }
# if ($templateParameters.parameters.logAnalytics.value.workspaceKey -eq "") {
#     $templateParameters.parameters.logAnalytics.value.workspaceKey = $logAnalytics.workspaceKey
# }
if ($templateParameters.parameters.virtualNetwork.value.name -eq "") {
    $templateParameters.parameters.virtualNetwork.value.name = $computeNetwork.name
}
if ($templateParameters.parameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
}
$managerDataTier = (az account get-access-token --resource https://ossrdbms-aad.database.windows.net) | ConvertFrom-Json
$templateParameters.parameters.renderManager.value.databaseAccessToken = $managerDataTier.accessToken

$templateParameters | ConvertTo-Json -Depth 5 | Set-Content -Path "$templateDirectory/$moduleDirectory/08-Manager.Machines.Parameters.$computeRegionName.json"
$templateParameters = "$templateDirectory/$moduleDirectory/08-Manager.Machines.Parameters.$computeRegionName.json"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$renderManager = $groupDeployment.properties.outputs.renderManager.value
$renderManager.hostAddress ?? ""
New-TraceMessage $moduleName $true $computeRegionName

Write-Output -InputObject $renderManager -NoEnumerate
