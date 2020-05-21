param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix,

    # Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
    [string[]] $computeRegionNames = @("WestUS2"),

    # Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
    [string[]] $storageRegionNames = @("WestUS2"),

    # Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
    [boolean] $storageObjectEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview)
    [boolean] $cacheEnable = $false,
    
    # The set of shared Azure services across regions, including Storage, Cache, Image Gallery, etc.
    [object] $sharedServices,

    # Set to the Azure Render Manager farm host (name or IP address) for each of the compute regions
    [string[]] $renderManagers
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
    $sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionNames, $storageNetAppEnable, $storageObjectEnable, $cacheEnable
    $sharedServices = Receive-Job -Job $sharedServicesJob -Wait
    if ($sharedServicesJob.JobStateInfo.State -eq "Failed") {
        Write-Host $sharedServicesJob.JobStateInfo.Reason
        return
    }
    New-TraceMessage $moduleName $true
}

$computeNetworks = $sharedServices.computeNetworks
$logAnalytics = $sharedServices.logAnalytics
$imageGallery = $sharedServices.imageGallery
$storageMounts = $sharedServices.storageMounts
$cacheMounts = $sharedServices.cacheMounts

$moduleDirectory = "ArtistDesktop"

# 11 - Desktop Machines
$artistDesktopMachines = @()
$moduleName = "11 - Desktop Machines"
$resourceGroupNameSuffix = "Desktop"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionIndex
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
    if (!$resourceGroup) { return }

    $templateResources = "$templateDirectory/$moduleDirectory/11-Desktop.Machines.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/11-Desktop.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters

    for ($machineTypeIndex = 0; $machineTypeIndex -lt $templateParameters.artistDesktop.value.machineTypes.length; $machineTypeIndex++) {
        if ($templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].enabled) {
            if ($templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].image.referenceId -eq "") {
                $imageTemplateName = $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].image.templateName
                $imageDefinitionName = $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].image.definitionName
                $imageVersionId = Get-ImageVersionId $imageGallery.resourceGroupName $imageGallery.name $imageDefinitionName $imageTemplateName
                $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].image.referenceId = $imageVersionId
            }
            if ($templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptCommands -eq "") {
                $scriptFile = $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptFile
                $scriptFile = "$templateDirectory/$moduleDirectory/$scriptFile"
                $scriptParameters = $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptParameters
                $imageDefinition = (az sig image-definition show --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
                if ($imageDefinition.osType -eq "Windows") {
                    $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts $true
                    $scriptParameters += " -fileSystemMounts '" + $fileSystemMounts + "'"
                    if ($renderManagers.length -gt $computeRegionIndex) {
                        $scriptParameters += " -openCueRenderManagerHost " + $renderManagers[$computeRegionIndex]
                    }
                    $scriptCommands = Get-ScriptCommands $scriptFile $scriptParameters
                    $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptParameters = ""
                } else {
                    $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts $false
                    $scriptParameters += " FILE_SYSTEM_MOUNTS='" + $fileSystemMounts + "'"
                    if ($renderManagers.length -gt $computeRegionIndex) {
                        $scriptParameters += " OPENCUE_RENDER_MANAGER_HOST=" + $renderManagers[$computeRegionIndex]
                    }
                    $scriptCommands = Get-ScriptCommands $scriptFile
                    $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptParameters = $scriptParameters
                }
                $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptCommands = $scriptCommands
            }
        }
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
    
    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { return }

    $artistDesktopMachines += $groupDeployment.properties.outputs.artistDesktopMachines.value
    New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

Write-Output -InputObject $artistDesktopMachines -NoEnumerate
