param (
    # Set a name prefix for the Azure resource groups that are created by this automated deployment script
    [string] $resourceGroupNamePrefix = "ArtistAnywhere",

    # Set the Azure region name for compute resources (e.g., Image Gallery, Virtual Machine Scale Set, HPC Cache, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for storage resources (e.g., Storage Network, Storage Account, File Share / Container, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure VPN Gateway services (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $networkGatewayDeploy = $false,

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppDeploy = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview) in the compute region
    [boolean] $storageCacheDeploy = $false,

    # Set to the target Azure render management deployment mode (i.e., OpenCue[.CycleCloud], Deadline[.CycleCloud] or Batch)
    [string] $renderManagerMode = "OpenCue",

    # Set the operating system type (i.e., Linux or Windows) for the Azure render manager/node images and virtual machines
    [string] $renderFarmType = "Linux",

    # Set the operating system type (i.e., Linux or Windows) for the Azure artist workstation image and virtual machines
    [string] $artistWorkstationType = "Linux"
)

$rootDirectory = $PSScriptRoot
$moduleDirectory = "RenderFarm"

Import-Module "$rootDirectory/Deploy.psm1"

# Base Framework
$baseFramework = Get-BaseFramework $rootDirectory $resourceGroupNamePrefix $computeRegionName $storageRegionName $networkGatewayDeploy
$computeNetwork = $baseFramework.computeNetwork
$managedIdentity = $baseFramework.managedIdentity
$logAnalytics = $baseFramework.logAnalytics
$imageGallery = $baseFramework.imageGallery
$containerRegistry = $baseFramework.containerRegistry

# Storage Cache
$storageCache = Get-StorageCache $baseFramework $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppDeploy $storageCacheDeploy
$storageMounts = $storageCache.storageMounts
$cacheMount = $storageCache.cacheMount

# Render Manager Job
$renderManagerModuleName = "Render Manager Job"
New-TraceMessage $renderManagerModuleName $false
$renderManagerJob = Start-Job -FilePath "$rootDirectory/RenderManager/Deploy.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $renderManagerMode, $renderFarmType, $baseFramework, $storageCache

# Artist Workstation Image Job
$workstationImageModuleName = "Artist Workstation Image [$artistWorkstationType] Job"
New-TraceMessage $workstationImageModuleName $false
$workstationImageJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Image.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $artistWorkstationType, $baseFramework, $storageCache

# 15.0 - Render Node Image Template
$moduleName = "15.0 - Render Node Image Template"
New-TraceMessage $moduleName $false $computeRegionName
$resourceGroupNameSuffix = ".Gallery"
$resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

$imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/15-Node.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
$deployEnabled = Set-ImageTemplates $resourceGroupName $imageTemplates $renderFarmType

if ($deployEnabled) {
    $templateFile = "$rootDirectory/$moduleDirectory/15-Node.Image.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/15-Node.Image.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.imageGallery.value.name = $imageGallery.name
    $templateConfig.parameters.imageGallery.value.resourceGroupName = $imageGallery.resourceGroupName
    foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
        if ($imageTemplate.imageOperatingSystemType -eq "Windows") {
            $scriptDirectory = "Windows"
            $scriptFileType = "PowerShell"
            $scriptFileExtension = ".ps1"
            $downloadsPath = "C:\Windows\Temp\"
        } else {
            $scriptDirectory = "Linux"
            $scriptFileType = "Shell"
            $scriptFileExtension = ".sh"
            $downloadsPath = "/tmp/"
        }
        $imageTemplate.buildCustomization = @()
        foreach ($storageMount in $storageMounts) {
            $scriptFile = Get-MountUnitFileName $storageMount
            $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
            $scriptChecksum = Get-ScriptChecksum $rootDirectory "StorageCache" "" $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "$downloadsPath$scriptFile"
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }
        $scriptFile = Get-MountUnitFileName $cacheMount
        $scriptUri = Get-ScriptUri $storageAccounts $scriptFile
        $scriptChecksum = Get-ScriptChecksum $rootDirectory "StorageCache" "" $scriptFile
        $buildCustomizer = New-Object PSObject
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value "File"
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "destination" -Value "$downloadsPath$scriptFile"
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
        $imageTemplate.buildCustomization += $buildCustomizer

        $scriptFile = "13-Node.Image$scriptFileExtension"
        $scriptUri = Get-ScriptUri $storageAccounts $scriptDirectory $scriptFile
        $scriptChecksum = Get-ScriptChecksum $rootDirectory $moduleDirectory $scriptDirectory $scriptFile
        $buildCustomizer = New-Object PSObject
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
        $imageTemplate.buildCustomization += $buildCustomizer

        $scriptFile = "13-Node.Image.Blender$scriptFileExtension"
        $scriptUri = Get-ScriptUri $storageAccounts $scriptDirectory $scriptFile
        $scriptChecksum = Get-ScriptChecksum $rootDirectory $moduleDirectory $scriptDirectory $scriptFile
        $buildCustomizer = New-Object PSObject
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
        $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
        $imageTemplate.buildCustomization += $buildCustomizer

        if ($renderManagerMode.Contains("OpenCue")) {
            $scriptFile = "13-Node.Image.OpenCue$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptDirectory $scriptFile
            $scriptChecksum = Get-ScriptChecksum $rootDirectory $moduleDirectory $scriptDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }

        if ($renderManagerMode.Contains("Deadline")) {
            $scriptFile = "13-Node.Image.Deadline$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptDirectory $scriptFile
            $scriptChecksum = Get-ScriptChecksum $rootDirectory $moduleDirectory $scriptDirectory $scriptFile
            $buildCustomizer = New-Object PSObject
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "type" -Value $scriptFileType
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
            $buildCustomizer | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptChecksum
            $imageTemplate.buildCustomization += $buildCustomizer
        }

        if (!$renderManagerMode.Contains("CycleCloud") -and $renderManagerMode -ne "Batch") {
            $scriptFile = "14-Farm.ScaleSet$scriptFileExtension"
            $scriptUri = Get-ScriptUri $storageAccounts $scriptDirectory $scriptFile
            $scriptChecksum = Get-ScriptChecksum $rootDirectory $moduleDirectory $scriptDirectory $scriptFile
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
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
}
New-TraceMessage $moduleName $true $computeRegionName

# 15.1 - Render Node Image Build
$moduleName = "15.1 - Render Node Image Build"
$imageTemplates = (Get-Content "$rootDirectory/$moduleDirectory/15-Node.Image.Parameters.json" -Raw | ConvertFrom-Json).parameters.imageTemplates.value
Build-ImageTemplates $moduleName $computeRegionName $imageGallery $imageTemplates

# Render Manager Job
$renderManager = Receive-Job -Job $renderManagerJob -Wait
New-TraceMessage $renderManagerModuleName $true

Receive-Job -Job $workstationImageJob -Wait
New-TraceMessage $workstationImageModuleName $true

# Artist Workstation Machine Job
$workstationMachineModuleName = "Artist Workstation Machine [$artistWorkstationType] Job"
New-TraceMessage $workstationMachineModuleName $false
$workstationMachineJob = Start-Job -FilePath "$rootDirectory/ArtistWorkstation/Deploy.Machine.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy, $baseFramework, $storageCache, $artistWorkstationType, $renderManager

# 16 - Farm Pool
if ($renderManagerMode -eq "Batch") {
    $moduleName = "16 - Farm Pool"
    New-TraceMessage $moduleName $false $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/16-Farm.Pool.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/16-Farm.Pool.Parameters.json"

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
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $renderManager.resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true $computeRegionName
}

# 16 - Farm Scale Set
if ($renderManagerMode -eq "OpenCue" -or $renderManagerMode -eq "Deadline") {
    $moduleName = "16 - Farm Scale Set"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Farm"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/16-Farm.ScaleSet.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/16-Farm.ScaleSet.Parameters.json"

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
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true $computeRegionName
}

Receive-Job -Job $workstationMachineJob -Wait
New-TraceMessage $workstationMachineModuleName $true
