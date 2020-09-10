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
    [object] $sharedServices,

    # The Azure render farm manager host names (or IP addresses)
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
    $sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames, $storageRegionName, $storageNetAppEnable, $storageCacheEnable
    $sharedServices = Receive-Job -Job $sharedServicesJob -Wait
    if (!$?) { return }
    New-TraceMessage $moduleName $true
}

$computeNetworks = $sharedServices.computeNetworks
$userIdentity = $sharedServices.userIdentity
$logAnalytics = $sharedServices.logAnalytics
$storageMounts = $sharedServices.storageMounts
$cacheMounts = $sharedServices.cacheMounts
$imageGallery = $sharedServices.imageGallery

$moduleDirectory = "ArtistDesktop"

# 12 - Desktop Machines
$artistDesktopMachines = @()
$moduleName = "12 - Desktop Machines"
$resourceGroupNameSuffix = ".Desktop"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionNames[$computeRegionIndex]
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
    if (!$resourceGroup) { throw }

    $templateFile = "$templateDirectory/$moduleDirectory/12-Desktop.Machines.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/12-Desktop.Machines.Parameters.json" -Raw | ConvertFrom-Json).parameters

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
                    $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
                    $scriptParameters += " -fileSystemMounts '" + $fileSystemMounts + "'"
                    if ($renderManagers.length -gt $computeRegionIndex) {
                        $scriptParameters += " -openCueRenderManagerHost " + $renderManagers[$computeRegionIndex]
                    }
                    $scriptCommands = Get-ScriptCommands $scriptFile $scriptParameters
                    $templateParameters.artistDesktop.value.machineTypes[$machineTypeIndex].customExtension.scriptParameters = ""
                } else {
                    $fileSystemMounts = Get-FileSystemMounts $storageMounts $cacheMounts
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
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { throw }

    $artistDesktopMachines += $groupDeployment.properties.outputs.artistDesktopMachines.value
    New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $true

Write-Output -InputObject $artistDesktopMachines -NoEnumerate
