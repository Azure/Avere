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
    [boolean] $storageCacheEnable = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# * - Shared Services Job
$moduleName = "* - Shared Services Job"
New-TraceMessage $moduleName $false
$sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable
$sharedServices = Receive-Job -Job $sharedServicesJob -Wait
if (!$?) { return }
New-TraceMessage $moduleName $true

$computeNetworks = $sharedServices.computeNetworks
$userIdentity = $sharedServices.userIdentity
$logAnalytics = $sharedServices.logAnalytics
$storageMounts = $sharedServices.storageMounts
$cacheMounts = $sharedServices.cacheMounts
$imageGallery = $sharedServices.imageGallery

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
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "09.0 - Worker Image Template"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { throw }

$templateFile = "$templateDirectory/$moduleDirectory/09-Worker.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/09-Worker.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.renderWorker.value.userIdentityId -eq "") {
    $templateParameters.renderWorker.value.userIdentityId = $userIdentity.resourceId
}
if ($templateParameters.imageGallery.value.name -eq "") {
    $templateParameters.imageGallery.value.name = $imageGallery.name
}
if ($templateParameters.imageGallery.value.replicationRegions.length -eq 0) {
    $templateParameters.imageGallery.value.replicationRegions = $computeRegionNames
}
if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 7).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { throw }
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 09.1 - Worker Image Version
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "09.1 - Worker Image Version"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/09-Worker.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
foreach ($machineImage in $templateParameters.renderWorker.value.machineImages) {
    if ($machineImage.enabled) {
        New-TraceMessage "$moduleName [$($machineImage.templateName)]" $false $computeRegionNames[$computeRegionIndex]
        $imageVersionId = Get-ImageVersionId $resourceGroupName $imageGallery.name $machineImage.definitionName $machineImage.templateName
        if (!$imageVersionId) {
            az image builder run --resource-group $resourceGroupName --name $machineImage.templateName
        }
        New-TraceMessage "$moduleName [$($machineImage.templateName)]" $true $computeRegionNames[$computeRegionIndex]
    }
}
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# * - Render Manager Job
$moduleName = "* - Render Manager Job"
$renderManagers = Receive-Job -Job $renderManagersJob -Wait
if (!$?) { return }
New-TraceMessage $moduleName $true

# * - Artist Desktop Images Job
$moduleName = "* - Artist Desktop Images Job"
$artistDesktopImages = Receive-Job -Job $artistDesktopImagesJob -Wait
if (!$?) { return }
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
New-TraceMessage $moduleName $false
$artistDesktopMachinesJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistDesktop.Machines.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices, $renderManagers

# 10 - Worker Machines
$moduleName = "10 - Worker Machines"
$resourceGroupNameSuffix = ".Worker"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionNames[$computeRegionIndex]
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
    if (!$resourceGroup) { throw }

    $templateFile = "$templateDirectory/$moduleDirectory/10-Worker.Machines.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/10-Worker.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters
    $scriptCommands = Get-ScriptCommands "$templateDirectory/$moduleDirectory/10-Worker.Machines.sh"

    if ($templateParameters.renderWorker.value.image.referenceId -eq "") {
        $imageTemplateName = $templateParameters.renderWorker.value.image.templateName
        $imageDefinitionName = $templateParameters.renderWorker.value.image.definitionName
        $imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
        $templateParameters.renderWorker.value.image.referenceId = $imageVersionId
    }
    if ($templateParameters.renderWorker.value.scriptCommands -eq "") {
        $templateParameters.renderWorker.value.scriptCommands = $scriptCommands
    }
    if ($templateParameters.renderWorker.value.fileSystemMounts -eq "") {
        $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
        $templateParameters.renderWorker.value.fileSystemMounts = $fileSystemMounts
    }
    if ($templateParameters.renderManager.value.hostAddress -eq "") {
        $templateParameters.renderManager.value.hostAddress = $renderManagers[$computeRegionIndex]
    }
    # if ($templateParameters.logAnalytics.value.workspaceId -eq "") {
    #     $templateParameters.logAnalytics.value.workspaceId = $logAnalytics.workspaceId
    # }
    # if ($templateParameters.logAnalytics.value.workspaceKey -eq "") {
    #     $templateParameters.logAnalytics.value.workspaceKey = $logAnalytics.workspaceKey
    # }
    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { throw }
    New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

# * - Artist Desktop Machines Job
$moduleName = "* - Artist Desktop Machines Job"
$artistDesktopMachines = Receive-Job -Job $artistDesktopMachinesJob -Wait
if (!$?) { return }
New-TraceMessage $moduleName $true
