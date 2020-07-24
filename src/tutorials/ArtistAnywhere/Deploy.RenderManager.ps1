param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name(s) for Compute resources (e.g., Image Builder, Virtual Machines, HPC Cache, etc.)
    [string[]] $computeRegionNames = @("EastUS2", "WestUS2"),

    # Set the Azure region name for Storage resources (e.g., VPN Gateway, NetApp Files, Object (Blob) Storage, etc.)
    [string] $storageRegionName = $computeRegionNames[0],

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false,

    # The shared Azure services (e.g., Virtual Networks, Managed Identity, Log Analytics, etc.)
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
    $sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable
    $sharedServices = Receive-Job -Job $sharedServicesJob -Wait
    if (!$?) { return }
    New-TraceMessage $moduleName $true
}

$computeNetworks = $sharedServices.computeNetworks
$userIdentity = $sharedServices.userIdentity
$logAnalytics = $sharedServices.logAnalytics
$storageMounts = $sharedServices.storageMounts
$imageGallery = $sharedServices.imageGallery

$moduleDirectory = "RenderManager"

# 06 - Manager Data
$managerDatabaseSql = @()
$managerDatabaseAdminName = @()
$managerDatabaseAdminLogin = @()
$managerDatabaseAdminPassword = @()
$managerDatabaseUrl = @()
$managerDatabaseUserName = @()
$managerDatabaseUserLogin = @()
$moduleName = "06 - Manager Data"
$resourceGroupNameSuffix = ".Manager"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    $computeRegionName = $computeRegionNames[$computeRegionIndex]
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionNames[$computeRegionIndex]
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
    if (!$resourceGroup) { throw }

    $templateFile = "$templateDirectory/$moduleDirectory/06-Manager.Data.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/06-Manager.Data.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { throw }

    $managerDatabaseSql += $groupDeployment.properties.outputs.managerDatabaseSql.value
    $managerDatabaseAdminName += $groupDeployment.properties.outputs.managerDatabaseAdminName.value
    $managerDatabaseAdminLogin += $groupDeployment.properties.outputs.managerDatabaseAdminLogin.value
    $managerDatabaseAdminPassword += $groupDeployment.properties.outputs.managerDatabaseAdminPassword.value
    $managerDatabaseUrl += $groupDeployment.properties.outputs.managerDatabaseUrl.value
    $managerDatabaseUserName += $groupDeployment.properties.outputs.managerDatabaseUserName.value
    $managerDatabaseUserLogin += $groupDeployment.properties.outputs.managerDatabaseUserLogin.value
    New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

# 07.0 - Manager Image Template
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "07.0 - Manager Image Template"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { throw }

$templateFile = "$templateDirectory/$moduleDirectory/07-Manager.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/07-Manager.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.userIdentity.value.name -eq "") {
    $templateParameters.userIdentity.value.name = $userIdentity.name
}
if ($templateParameters.userIdentity.value.resourceGroupName -eq "") {
    $templateParameters.userIdentity.value.resourceGroupName = $userIdentity.resourceGroupName
}
if ($templateParameters.imageGallery.value.name -eq "") {
    $templateParameters.imageGallery.value.name = $imageGallery.name
}
if ($templateParameters.imageGallery.value.replicationRegions.length -eq 0) {
    $templateParameters.imageGallery.value.replicationRegions = $computeRegionNames
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 7).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
# if (!$groupDeployment) { throw }
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 07.1 - Manager Image Version
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "07.1 - Manager Image Version"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/07-Manager.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($imageTemplate in $templateParameters.imageTemplates.value) {
    if ($imageTemplate.enabled) {
        New-TraceMessage "$moduleName [$($imageTemplate.templateName)]" $false $computeRegionNames[$computeRegionIndex]
        $imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $imageTemplate.definitionName $imageTemplate.templateName
        if (!$imageVersionId) {
            az image builder run --resource-group $resourceGroupName --name $imageTemplate.templateName
        }
        New-TraceMessage "$moduleName [$($imageTemplate.templateName)]" $true $computeRegionNames[$computeRegionIndex]
    }
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 08 - Manager Machines
$renderManagers = @()
$moduleName = "08 - Manager Machines"
$resourceGroupNameSuffix = ".Manager"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionNames[$computeRegionIndex]
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
    if (!$resourceGroup) { throw }

    $templateFile = "$templateDirectory/$moduleDirectory/08-Manager.Machines.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/08-Manager.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
    $scriptCommands = Get-ScriptCommands "$templateDirectory/$moduleDirectory/08-Manager.Machines.sh"

    if ($templateParameters.userIdentity.value.name -eq "") {
        $templateParameters.userIdentity.value.name = $userIdentity.name
    }
    if ($templateParameters.userIdentity.value.resourceGroupName -eq "") {
        $templateParameters.userIdentity.value.resourceGroupName = $userIdentity.resourceGroupName
    }
    if ($templateParameters.renderManager.value.image.referenceId -eq "") {
        $imageTemplateName = $templateParameters.renderManager.value.image.templateName
        $imageDefinitionName = $templateParameters.renderManager.value.image.definitionName
        $imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
        $templateParameters.renderManager.value.image.referenceId = $imageVersionId
    }
    if ($templateParameters.renderManager.value.scriptCommands -eq "") {
        $templateParameters.renderManager.value.scriptCommands = $scriptCommands
    }
    if ($templateParameters.renderManager.value.databaseSql -eq "") {
        $templateParameters.renderManager.value.databaseSql = $managerDatabaseSql[$computeRegionIndex]
    }
    if ($templateParameters.renderManager.value.databaseAdminName -eq "") {
        $templateParameters.renderManager.value.databaseAdminName = $managerDatabaseAdminName[$computeRegionIndex]
    }
    if ($templateParameters.renderManager.value.databaseAdminLogin -eq "") {
        $templateParameters.renderManager.value.databaseAdminLogin = $managerDatabaseAdminLogin[$computeRegionIndex]
    }
    if ($templateParameters.renderManager.value.databaseAdminPassword -eq "") {
        $templateParameters.renderManager.value.databaseAdminPassword = $managerDatabaseAdminPassword[$computeRegionIndex]
    }
    if ($templateParameters.renderManager.value.databaseUrl -eq "") {
        $templateParameters.renderManager.value.databaseUrl = $managerDatabaseUrl[$computeRegionIndex]
    }
    if ($templateParameters.renderManager.value.databaseUserName -eq "") {
        $templateParameters.renderManager.value.databaseUserName = $managerDatabaseUserName[$computeRegionIndex]
    }
    if ($templateParameters.renderManager.value.databaseUserLogin -eq "") {
        $templateParameters.renderManager.value.databaseUserLogin = $managerDatabaseUserLogin[$computeRegionIndex]
    }
    if ($templateParameters.logAnalytics.value.workspaceId -eq "") {
        $templateParameters.logAnalytics.value.workspaceId = $logAnalytics.workspaceId
    }
    if ($templateParameters.logAnalytics.value.workspaceKey -eq "") {
        $templateParameters.logAnalytics.value.workspaceKey = $logAnalytics.workspaceKey
    }
    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { throw }
    
    $renderManagers += $groupDeployment.properties.outputs.renderManager.value
    New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

Write-Output -InputObject $renderManagers -NoEnumerate
