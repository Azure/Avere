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
    [object] $sharedServices,

    # The Azure storage (e.g., Blob, NetApp Files, etc.) and cache (e.g., HPC Cache) services
    [object] $storageCache,

    # The Azure render farm manager
    [object] $renderManager
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
$logAnalytics = $sharedServices.logAnalytics
$imageGallery = $sharedServices.imageGallery

# * - Storage Cache Job
if (!$storageCache) {
    $moduleName = "* - Storage Cache Job"
    New-TraceMessage $moduleName $false
    $storageCacheJob = Start-Job -FilePath "$templateDirectory/Deploy.StorageCache.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $storageCacheEnable, $sharedServices
    $storageCache = Receive-Job -Job $storageCacheJob -Wait
    New-TraceMessage $moduleName $true
}
$storageMounts = $storageCache.storageMounts
$cacheMounts = $storageCache.cacheMounts

$moduleDirectory = "ArtistDesktop"

# 12 - Desktop Machines
$artistDesktops = @()
$moduleName = "12 - Desktop Machines"
$resourceGroupNameSuffix = ".Desktop"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

$templateFile = "$templateDirectory/$moduleDirectory/12-Desktop.Machines.json"
$templateParameters = Get-Content "$templateDirectory/$moduleDirectory/12-Desktop.Machines.Parameters.json" -Raw | ConvertFrom-Json

for ($machineIndex = 0; $machineIndex -lt $templateParameters.parameters.artistDesktops.value.length; $machineIndex++) {
    if ($templateParameters.parameters.artistDesktops.value[$machineIndex].enabled) {
        if ($templateParameters.parameters.artistDesktops.value[$machineIndex].image.referenceId -eq "") {
            $imageTemplateName = $templateParameters.parameters.artistDesktops.value[$machineIndex].image.templateName
            $imageDefinitionName = $templateParameters.parameters.artistDesktops.value[$machineIndex].image.definitionName
            $imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
            $templateParameters.parameters.artistDesktops.value[$machineIndex].image.referenceId = $imageVersionId
        }
        if ($templateParameters.parameters.artistDesktops.value[$machineIndex].customExtension.scriptCommands -eq "") {
            $scriptFile = $templateParameters.parameters.artistDesktops.value[$machineIndex].customExtension.scriptFile
            $scriptFile = "$templateDirectory/$moduleDirectory/$scriptFile"
            $scriptParameters = $templateParameters.parameters.artistDesktops.value[$machineIndex].customExtension.scriptParameters
            $imageDefinition = (az sig image-definition show --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
            if ($imageDefinition.osType -eq "Windows") {
                $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
                $scriptParameters += " -fileSystemMounts '" + $fileSystemMounts + "'"
                $scriptParameters += " -renderManagerHost '" + $renderManager.hostAddress + "'"
                $scriptCommands = Get-ScriptCommands $scriptFile $scriptParameters
                $templateParameters.parameters.artistDesktops.value[$machineIndex].customExtension.scriptParameters = ""
            } else {
                $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
                $scriptParameters += " FILE_SYSTEM_MOUNTS='" + $fileSystemMounts + "'"
                $scriptParameters += " RENDER_MANAGER_HOST='" + $renderManager.hostAddress + "'"
                $scriptCommands = Get-ScriptCommands $scriptFile
                $templateParameters.parameters.artistDesktops.value[$machineIndex].customExtension.scriptParameters = $scriptParameters
            }
            $templateParameters.parameters.artistDesktops.value[$machineIndex].customExtension.scriptCommands = $scriptCommands
        }
    }
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

$templateParameters | ConvertTo-Json -Depth 5 | Set-Content -Path "$templateDirectory/$moduleDirectory/12-Desktop.Machines.Parameters.$computeRegionName.json"
$templateParameters = "$templateDirectory/$moduleDirectory/12-Desktop.Machines.Parameters.$computeRegionName.json"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$artistDesktops = $groupDeployment.properties.outputs.artistDesktops.value
New-TraceMessage $moduleName $true $computeRegionName

Write-Output -InputObject $artistDesktops -NoEnumerate
