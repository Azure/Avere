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

    # Set to the target Azure render manager deployment configuration mode (i.e., CycleCloud, OpenCue, or Batch)
    [string] $renderManagerMode = "CycleCloud",

    # Set to true to deploy Azure artist workstations (image building, machine deployment, custom scripts, etc.)
    [boolean] $artistWorkstationDeploy = $false
)

$templateDirectory = $PSScriptRoot

Import-Module "$templateDirectory/Deploy.psm1"

# Shared Framework
$sharedFramework = Get-SharedFramework $resourceGroupNamePrefix $sharedRegionName $computeRegionName $storageRegionName
$computeNetwork = Get-VirtualNetwork $sharedFramework.computeNetworks $computeRegionName
$managedIdentity = $sharedFramework.managedIdentity
$logAnalytics = $sharedFramework.logAnalytics
$imageGallery = $sharedFramework.imageGallery
$containerRegistry = $sharedFramework.containerRegistry

# Storage Cache
$storageCache = Get-StorageCache $sharedFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
$storageAccounts = $storageCache.storageAccounts
$storageMounts = $storageCache.storageMounts
$cacheMounts = $storageCache.cacheMounts

# Render Manager Job
$moduleName = "Render Manager Job"
New-TraceMessage $moduleName $false
$renderManagerJob = Start-Job -FilePath "$templateDirectory/Deploy.RenderManager.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $renderManagerMode, $sharedFramework, $storageCache

if ($artistWorkstationDeploy) {
    # Artist Workstation Image [Linux] Job
    $moduleNameImageLinux = "Artist Workstation Image [Linux] Job"
    New-TraceMessage $moduleNameImageLinux $false
    $workstationImageLinuxJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Image.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

    # Artist Workstation Image [Windows] Job
    $moduleNameImageWindows = "Artist Workstation Image [Windows] Job"
    New-TraceMessage $moduleNameImageWindows $false
    $workstationImageWindowsJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Image.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache
}

$moduleDirectory = "RenderFarm"

# 13.0 - Render Node Image Template
$moduleName = "13.0 - Render Node Image Template"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupNameSuffix = ".Gallery"
$resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$imageTemplates = (Get-Content "$templateDirectory/$moduleDirectory/13-Node.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value

if (Confirm-ImageTemplates $resourceGroupName $imageTemplates) {
    $templateFile = "$templateDirectory/$moduleDirectory/13-Node.Image.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/13-Node.Image.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
        $imageTemplate.buildCustomization = @()
        foreach ($storageMount in $storageMounts) {
            $scriptFile = Get-MountUnitFileName $storageMount
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum "StorageCache" $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "/tmp/$scriptFile"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
        foreach ($cacheMount in $cacheMounts) {
            $scriptFile = Get-MountUnitFileName $cacheMount
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum "StorageCache" $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "/tmp/$scriptFile"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
        $scriptFile = "13-Node.Image.sh"
        $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
        $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
        $buildCustomizer = New-Object PSObject
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "Shell"
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
        $imageTemplate.buildCustomization += $buildCustomizer
        $scriptFile = "13-Node.Image.Blender.sh"
        $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
        $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
        $buildCustomizer = New-Object PSObject
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "Shell"
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
        $imageTemplate.buildCustomization += $buildCustomizer
        if ($renderManagerMode -ne "Batch") {
            $scriptFile = "13-Node.Image.OpenCue.sh"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "Shell"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
            $scriptFile = "14-Farm.ScaleSet.sh"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "/tmp/$scriptFile"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
    }
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
}
New-TraceMessage $moduleName $true $computeRegionName

# 13.1 - Render Node Image Build
$moduleName = "13.1 - Render Node Image Build"
New-TraceMessage $moduleName $false $computeRegionName
foreach ($imageTemplate in $imageTemplates) {
    $imageVersion = Get-ImageVersion $imageGallery $imageTemplate
    if (!$imageVersion) {
        New-TraceMessage "$moduleName [$($imageTemplate.name)]" $false $computeRegionName
        $imageBuild = az image builder run --resource-group $resourceGroupName --name $imageTemplate.name
        New-TraceMessage "$moduleName [$($imageTemplate.name)]" $true $computeRegionName
    }
}
New-TraceMessage $moduleName $true $computeRegionName

# Render Manager Job
$moduleName = "Render Manager Job"
$renderManager = Receive-Job -Job $renderManagerJob -Wait
New-TraceMessage $moduleName $true

if ($artistWorkstationDeploy) {
    Receive-Job -Job $workstationImageLinuxJob -Wait
    New-TraceMessage $moduleNameImageLinux $true

    # Artist Workstation Machine [Linux] Job
    $moduleNameMachineLinux = "Artist Workstation Machine [Linux] Job"
    New-TraceMessage $moduleNameMachineLinux $false
    $workstationMachineLinuxJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Machine.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache, $renderManager

    Receive-Job -Job $workstationImageWindowsJob -Wait
    New-TraceMessage $moduleNameImageWindows $true

    # Artist Workstation Machine [Windows] Job
    $moduleNameMachineWindows = "Artist Workstation Machine [Windows] Job"
    New-TraceMessage $moduleNameMachineWindows $false
    $workstationMachineWindowsJob = Start-Job -FilePath "$templateDirectory/Deploy.ArtistWorkstation.Machine.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache, $renderManager
}

# 14 - Farm Pool
if ($renderManagerMode -eq "Batch") {
    $moduleName = "14 - Farm Pool"
    New-TraceMessage $moduleName $false $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/14-Farm.Pool.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/14-Farm.Pool.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    $templateConfig.parameters.containerRegistry.value.name = $containerRegistry.name
    $templateConfig.parameters.containerRegistry.value.resourceGroupName = $containerRegistry.resourceGroupName
    $templateConfig.parameters.containerRegistry.value.loginEndpoint = $containerRegistry.loginEndpoint
    $templateConfig.parameters.containerRegistry.value.loginPassword = $containerRegistry.loginPassword
    $templateConfig.parameters.renderManager.value.name = $renderManager.name
    $templateConfig.parameters.renderManager.value.resourceGroupName = $renderManager.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $renderManager.resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true $computeRegionName
}

# 14 - Farm Scale Set
if ($renderManagerMode -eq "OpenCue") {
    $moduleName = "14 - Farm Scale Set"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Farm"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    
    $templateFile = "$templateDirectory/$moduleDirectory/14-Farm.ScaleSet.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/14-Farm.ScaleSet.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName

    $scriptParameters = $templateConfig.parameters.scriptExtension.value.scriptParameters
    $scriptParameters.RENDER_MANAGER_HOST = $renderManager.host
    $fileParameters = Get-ObjectProperties $scriptParameters $false
    $templateConfig.parameters.scriptExtension.value.fileParameters = $fileParameters

    $templateConfig.parameters.logAnalytics.value.name = $logAnalytics.name
    $templateConfig.parameters.logAnalytics.value.resourceGroupName = $logAnalytics.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 7 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true $computeRegionName
}

# Artist Workstation Machine Job
if ($artistWorkstationDeploy) {
    Receive-Job -Job $workstationMachineLinuxJob -Wait
    New-TraceMessage $moduleNameMachineLinux $true
    
    Receive-Job -Job $workstationMachineWindowsJob -Wait
    New-TraceMessage $moduleNameMachineWindows $true
}
