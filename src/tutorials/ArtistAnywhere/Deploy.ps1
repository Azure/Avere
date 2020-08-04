param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name(s) for Compute resources (e.g., Image Builder, Virtual Machines, HPC Cache, etc.)
    [string[]] $computeRegionNames = @("WestUS2"),

    # Set the Azure region name for Storage resources (e.g., Virtual Network, Object (Blob) Storage, NetApp Files, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
$moduleName = "* - Shared Services Job"
New-TraceMessage $moduleName $false
$sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames
$sharedServices = Receive-Job -Job $sharedServicesJob -Wait
$computeNetworks = $sharedServices.computeNetworks
$userIdentity = $sharedServices.userIdentity
$logAnalytics = $sharedServices.logAnalytics
$imageGallery = $sharedServices.imageGallery
New-TraceMessage $moduleName $true

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
New-TraceMessage $moduleName $false
$storageCacheJob = Start-Job -FilePath "$templateDirectory/Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
New-TraceMessage $moduleName $false
$renderManagersJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderManager.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
New-TraceMessage $moduleName $false
$artistDesktopImagesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Images.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices

$moduleDirectory = "RenderWorker"

# 09.0 - Worker Image Template
$computeRegionIndex = 0
$computeRegionName = $computeRegionNames[$computeRegionIndex]
$moduleName = "09.0 - Worker Image Template"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/09-Worker.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/09-Worker.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.userIdentity.value.resourceId -eq "") {
    $templateParameters.userIdentity.value.resourceId = $userIdentity.resourceId
}
if ($templateParameters.imageGallery.value.name -eq "") {
    $templateParameters.imageGallery.value.name = $imageGallery.name
}
if ($templateParameters.imageGallery.value.replicationRegions.length -eq 0) {
    $templateParameters.imageGallery.value.replicationRegions = $computeRegionNames
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 7).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

New-TraceMessage $moduleName $true $computeRegionName

# 09.1 - Worker Image Version
$computeRegionIndex = 0
$computeRegionName = $computeRegionNames[$computeRegionIndex]
$moduleName = "09.1 - Worker Image Version"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/09-Worker.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
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

# * - Storage Cache Job
$moduleName = "* - Storage Cache Job"
$storageCache = Receive-Job -Job $storageCacheJob -Wait
$storageMounts = $storageCache.storageMounts
$cacheMounts = $storageCache.cacheMounts
New-TraceMessage $moduleName $true

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
$renderManagers = Receive-Job -Job $renderManagersJob -Wait
New-TraceMessage $moduleName $true

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
$artistDesktopImages = Receive-Job -Job $artistDesktopImagesJob -Wait
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
New-TraceMessage $moduleName $false
$artistDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices, $storageCache, $renderManagers

# 10 - Worker Machines
$moduleName = "10 - Worker Machines"
$resourceGroupNameSuffix = ".Worker"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    $computeRegionName = $computeRegionNames[$computeRegionIndex]
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/10-Worker.Machines.json"
    $templateParameters = Get-Content "$templateDirectory/$moduleDirectory/10-Worker.Machines.Parameters.json" -Raw | ConvertFrom-Json
    $scriptCommands = Get-ScriptCommands "$templateDirectory/$moduleDirectory/10-Worker.Machines.sh"

    if ($templateParameters.parameters.userIdentity.value.resourceId -eq "") {
        $templateParameters.parameters.userIdentity.value.resourceId = $userIdentity.resourceId
    }
    if ($templateParameters.parameters.renderWorker.value.image.referenceId -eq "") {
        $imageTemplateName = $templateParameters.parameters.renderWorker.value.image.templateName
        $imageDefinitionName = $templateParameters.parameters.renderWorker.value.image.definitionName
        $imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
        $templateParameters.parameters.renderWorker.value.image.referenceId = $imageVersionId
    }
    if ($templateParameters.parameters.renderWorker.value.scriptCommands -eq "") {
        $templateParameters.parameters.renderWorker.value.scriptCommands = $scriptCommands
    }
    if ($templateParameters.parameters.renderWorker.value.fileSystemMounts -eq "") {
        $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
        $templateParameters.parameters.renderWorker.value.fileSystemMounts = $fileSystemMounts
    }
    if ($templateParameters.parameters.renderManager.value.hostAddress -eq "") {
        $templateParameters.parameters.renderManager.value.hostAddress = $renderManagers[$computeRegionIndex]
    }
    # if ($templateParameters.parameters.logAnalytics.value.workspaceId -eq "") {
    #     $templateParameters.parameters.logAnalytics.value.workspaceId = $logAnalytics.workspaceId
    # }
    # if ($templateParameters.parameters.logAnalytics.value.workspaceKey -eq "") {
    #     $templateParameters.parameters.logAnalytics.value.workspaceKey = $logAnalytics.workspaceKey
    # }
    if ($templateParameters.parameters.virtualNetwork.value.name -eq "") {
        $templateParameters.parameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
    }
    if ($templateParameters.parameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.parameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
    }

    $templateParameters | ConvertTo-Json -Depth 5 | Set-Content -Path "$templateDirectory/$moduleDirectory/10-Worker.Machines.Parameters.$computeRegionName.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/10-Worker.Machines.Parameters.$computeRegionName.json"
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
$artistDesktopMachines = Receive-Job -Job $artistDesktopMachinesJob -Wait
New-TraceMessage $moduleName $true
