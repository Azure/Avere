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

    # Set to true to deploy Azure Linux custom images and virtual machines for the render farm nodes
    [boolean] $renderFarmLinux = $false,

    # Set to true to deploy Azure Windows custom images and virtual machines for the render farm nodes
    [boolean] $renderFarmWindows = $false,

    # Set to true to deploy Azure artist workstations (i.e., image building, machine deployment, etc.)
    [boolean] $artistWorkstationDeploy = $false
)

$rootDirectory = $PSScriptRoot
$moduleDirectory = "RenderFarm"

Import-Module "$rootDirectory/Deploy.psm1"

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
$renderManagerModuleName = "Render Manager Job"
New-TraceMessage $renderManagerModuleName $false
$renderManagerJob = Start-Job -FilePath "$rootDirectory/RenderManager/Deploy.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $renderManagerMode, $sharedFramework, $storageCache

if ($artistWorkstationDeploy) {
    # Artist Workstation Image [Linux] Job
    $workstationImageLinuxModuleName = "Artist Workstation Image [Linux] Job"
    New-TraceMessage $workstationImageLinuxModuleName $false
    $workstationImageLinuxJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache

    # Artist Workstation Image [Windows] Job
    $workstationImageWindowsModuleName = "Artist Workstation Image [Windows] Job"
    New-TraceMessage $workstationImageWindowsModuleName $false
    $workstationImageWindowsJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache
}

# 13.0 - Render Node Image Template
$moduleName = "13.0 - Render Node Image Template"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupNameSuffix = ".Gallery"
$resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/13-Node.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value

if (Confirm-ImageTemplates $resourceGroupName $imageTemplates) {
    $templateFile = "$rootDirectory/$moduleDirectory/13-Node.Image.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/13-Node.Image.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.renderFarm.value.deployLinux = $renderFarmLinux
    $templateConfig.parameters.renderFarm.value.deployWindows = $renderFarmWindows
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
        if ($imageTemplate.imageOperatingSystemType -eq "Windows") {
            $downloadsPath = "C:\Windows\Temp\"
            $scriptFileType = "PowerShell"
            $scriptFileExtension = ".ps1"
        } else {
            $downloadsPath = "/tmp/"
            $scriptFileType = "Shell"
            $scriptFileExtension = ".sh"
        }
        $imageTemplate.buildCustomization = @()
        foreach ($storageMount in $storageMounts) {
            $scriptFile = Get-MountUnitFileName $storageMount
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum "StorageCache" $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "$downloadsPath$scriptFile"
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
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "$downloadsPath$scriptFile"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
        $scriptFile = "13-Node.Image$scriptFileExtension"
        $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
        $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
        $buildCustomizer = New-Object PSObject
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
        $imageTemplate.buildCustomization += $buildCustomizer
        if ($renderManagerMode -eq "VRayDR") {
            $scriptFile = "13-Node.Image.VRayDR$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        } else {
            $scriptFile = "13-Node.Image.Blender$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
        if ($renderManagerMode -eq "CycleCloud" -or $renderManagerMode -eq "OpenCue") {
            $scriptFile = "13-Node.Image.OpenCue$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
        if ($renderManagerMode -eq "OpenCue" -or $renderManagerMode -eq "VRayDR") {
            $scriptFile = "14-Farm.ScaleSet$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $moduleDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "$downloadsPath$scriptFile"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
    }
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 7 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
}
New-TraceMessage $moduleName $true $computeRegionName

# 13.1 - Render Node Image Build
$moduleName = "13.1 - Render Node Image Build"
$imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/13-Node.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $imageTemplates

# Render Manager Job
$renderManager = Receive-Job -Job $renderManagerJob -Wait
New-TraceMessage $renderManagerModuleName $true

if ($artistWorkstationDeploy) {
    Receive-Job -Job $workstationImageLinuxJob -Wait
    New-TraceMessage $workstationImageLinuxModuleName $true

    # Artist Workstation Machine [Linux] Job
    $workstationMachineLinuxModuleName = "Artist Workstation Machine [Linux] Job"
    New-TraceMessage $workstationMachineLinuxModuleName $false
    $workstationMachineLinuxJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.Linux.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache, $renderManager

    Receive-Job -Job $workstationImageWindowsJob -Wait
    New-TraceMessage $workstationImageWindowsModuleName $true

    # Artist Workstation Machine [Windows] Job
    $workstationMachineWindowsModuleName = "Artist Workstation Machine [Windows] Job"
    New-TraceMessage $workstationMachineWindowsModuleName $false
    $workstationMachineWindowsJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.Windows.ps1" -ArgumentList $resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $sharedFramework, $storageCache, $renderManager
}

# 14 - Farm Pool
if ($renderManagerMode -eq "Batch") {
    $moduleName = "14 - Farm Pool"
    New-TraceMessage $moduleName $false $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/14-Farm.Pool.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/14-Farm.Pool.Parameters.json"

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
if ($renderManagerMode -eq "OpenCue" -or $renderManagerMode -eq "VRayDR") {
    $moduleName = "14 - Farm Scale Set"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Farm"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/14-Farm.ScaleSet.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/14-Farm.ScaleSet.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName

    foreach ($renderFarm in $templateConfig.parameters.renderFarms.value) {
        $scriptParameters = $renderFarm.customExtension.scriptParameters
        if ($renderFarm.image.osType -eq "Windows") {
            $scriptParameters.renderManagerHost = $renderManager.host ?? ""
            $fileParameters = Get-ObjectProperties $scriptParameters $true
        } else {
            $scriptParameters.RENDER_MANAGER_HOST = $renderManager.host ?? ""
            $fileParameters = Get-ObjectProperties $scriptParameters $false
        }
        $renderFarm.customExtension.fileParameters = $fileParameters
    }

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
    New-TraceMessage $workstationMachineLinuxModuleName $true

    Receive-Job -Job $workstationMachineWindowsJob -Wait
    New-TraceMessage $workstationMachineWindowsModuleName $true
}
