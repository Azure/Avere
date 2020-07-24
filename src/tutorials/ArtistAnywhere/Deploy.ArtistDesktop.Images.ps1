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
$storageMounts = $sharedServices.storageMounts
$imageGallery = $sharedServices.imageGallery

$moduleDirectory = "ArtistDesktop"

# 11.0 - Desktop Image Template
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "11.0 - Desktop Image Template"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { throw }

$templateFile = "$templateDirectory/$moduleDirectory/11-Desktop.Images.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/11-Desktop.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters

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

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
# if (!$groupDeployment) { throw }
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 11.1 - Desktop Image Version
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "11.1 - Desktop Image Version"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/11-Desktop.Images.Parameters.json" -Raw | ConvertFrom-Json).parameters
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

Write-Output -InputObject $templateParameters.imageTemplates.value -NoEnumerate
