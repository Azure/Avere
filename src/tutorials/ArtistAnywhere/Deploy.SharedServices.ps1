param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name(s) for Compute resources (e.g., Shared Image Gallery, Container Registry, etc.)
    [string[]] $computeRegionNames = @("EastUS2", "WestUS2"),

    # Set the Azure region name for Storage resources (e.g., VPN Gateway, NetApp Files, Object (Blob) Storage, etc.)
    [string] $storageRegionName = $computeRegionNames[0],

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
    $templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

$moduleDirectory = "VirtualNetwork"

# 00 - Network
$computeNetworks = @()
$moduleName = "00 - Network"
$resourceGroupNameSuffix = ".Network"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
    $computeRegionName = $computeRegionNames[$computeRegionIndex]
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionNames[$computeRegionIndex]
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
    if (!$resourceGroup) { throw }

    $templateFile = "$templateDirectory/$moduleDirectory/00-Network.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/00-Network.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters

    if ($storageNetwork) {
        $templateParameters.storageNetwork.value = $storageNetwork
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 8).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { throw }

    $computeNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
    $computeNetwork | Add-Member -MemberType NoteProperty -Name "regionName" -Value $computeRegionName
    $computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    $computeNetworks += $computeNetwork
    if (!$storageNetwork) {
        $storageNetwork = $computeNetwork
    }
    New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

# 01 - Framework
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "01 - Framework"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { throw }

$templateFile = "$templateDirectory/$moduleDirectory/01-Framework.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/01-Framework.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { throw }

$userIdentity = $groupDeployment.properties.outputs.userIdentity.value
$userIdentity | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
$logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
$keyVault = $groupDeployment.properties.outputs.keyVault.value
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

$moduleDirectory = "StorageCache"

# 02 - Storage
$storageMounts = @()
$storageTargets = @()
$moduleName = "02 - Storage"
$resourceGroupNameSuffix = ".Storage"
New-TraceMessage $moduleName $false $storageRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName
if (!$resourceGroup) { throw }

$storageMountsObject = @()
$storageTargetsObject = @()
$templateFile = "$templateDirectory/$moduleDirectory/02-Storage.Object.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/02-Storage.Object.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $storageNetwork.name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { throw }

$storageMountsObject = $groupDeployment.properties.outputs.storageMounts.value
$storageTargetsObject = $groupDeployment.properties.outputs.storageTargets.value

# $storageMounts += $storageMountsObject
# $storageTargets += $storageTargetsObject

if ($storageNetAppEnable) {
    $storageMountsNetApp = @()
    $storageTargetsNetApp = @()
    $templateFile = "$templateDirectory/$moduleDirectory/02-Storage.NetApp.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/02-Storage.NetApp.Parameters.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $storageNetwork.name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    if (!$groupDeployment) { throw }

    $storageMountsNetApp = $groupDeployment.properties.outputs.storageMounts.value
    $storageTargetsTemp = $groupDeployment.properties.outputs.storageTargets.value

    foreach ($storageTargetTemp in $storageTargetsTemp) {
        $storageTargetIndex = -1
        for ($i = 0; $i -lt $storageTargetsNetApp.length; $i++) {
            if ($storageTargetsNetApp[$i].host -eq $storageTargetTemp.host) {
                $storageTargetIndex = $i
            }
        }
        if ($storageTargetIndex -ge 0) {
            $storageNetworkName = $groupDeployment.properties.parameters.virtualNetwork.value.name
            $storageTargetsNetApp[$storageTargetIndex].name = $storageNetworkName + ".NetApp"
            $storageTargetsNetApp[$storageTargetIndex].junctions += $storageTargetTemp.junctions
        } else {
            $storageTargetsNetApp += $storageTargetTemp
        }
    }

    $storageMounts += $storageMountsNetApp
    $storageTargets += $storageTargetsNetApp
}
New-TraceMessage $moduleName $true $storageRegionName

# 03 - Cache
$cacheMounts = @()
if ($storageCacheEnable) {
    $moduleName = "03 - Cache"
    $resourceGroupNameSuffix = ".Cache"
    New-TraceMessage $moduleName $false
    for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
        $computeRegionName = $computeRegionNames[$computeRegionIndex]
        New-TraceMessage $moduleName $false $computeRegionName
        $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionNames[$computeRegionIndex]
        $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
        if (!$resourceGroup) { throw }

        $templateFile = "$templateDirectory/$moduleDirectory/03-Cache.json"
        $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/03-Cache.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters

        if ($templateParameters.storageTargets.value.length -gt 0 -and $templateParameters.storageTargets.value[0].name -ne "") {
            $templateParameters.storageTargets.value += $storageTargets
        } else {
            $templateParameters.storageTargets.value = $storageTargets
        }
        if ($templateParameters.virtualNetwork.value.name -eq "") {
            $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
        }
        if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
            $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
        }

        $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        if (!$groupDeployment) { throw }

        $dnsRecordName = $groupDeployment.properties.outputs.virtualNetwork.value.subnetName.ToLower()
        az network private-dns record-set a delete --resource-group $computeNetworks[$computeRegionIndex].resourceGroupName --zone-name $computeNetworks[$computeRegionIndex].domainName --name $dnsRecordName --yes
        foreach ($cacheMountAddress in $groupDeployment.properties.outputs.mountAddresses.value) {
            $dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetworks[$computeRegionIndex].resourceGroupName --zone-name $computeNetworks[$computeRegionIndex].domainName --record-set-name $dnsRecordName --ipv4-address $cacheMountAddress) | ConvertFrom-Json
            if (!$dnsRecord) { throw }
        }

        $cacheClientMounts = @()
        foreach ($cacheTarget in $groupDeployment.properties.outputs.storageTargets.value) {
            foreach ($cacheTargetJunction in $cacheTarget.junctions) {
                $cacheClientMount = New-Object PSObject
                $cacheClientMount | Add-Member -MemberType NoteProperty -Name "exportHost" -Value $dnsRecord.fqdn
                $cacheClientMount | Add-Member -MemberType NoteProperty -Name "exportPath" -Value $cacheTargetJunction.namespacePath
                $cacheClientMount | Add-Member -MemberType NoteProperty -Name "directory" -Value $cacheTargetJunction.namespacePath
                $cacheClientMount | Add-Member -MemberType NoteProperty -Name "options" -Value $cacheTarget.mountOptions
                $cacheClientMount | Add-Member -MemberType NoteProperty -Name "drive" -Value $cacheTarget.mountDrive
                $cacheClientMounts += $cacheClientMount
            }
        }

        $cacheMounts += $cacheClientMounts
        New-TraceMessage $moduleName $true $computeRegionName
    }
    New-TraceMessage $moduleName $true
}

$moduleDirectory = "ImageLibrary"

# 04 - Image Gallery
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "04 - Image Gallery"
$resourceGroupNameSuffix = ".Gallery"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { throw }

$templateFile = "$templateDirectory/$moduleDirectory/04-Image.Gallery.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Image.Gallery.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.userIdentity.value.name -eq "") {
    $templateParameters.userIdentity.value.name = $userIdentity.name
}
if ($templateParameters.userIdentity.value.resourceGroupName -eq "") {
    $templateParameters.userIdentity.value.resourceGroupName = $userIdentity.resourceGroupName
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { throw }

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value
$imageGallery | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 05 - Image Registry
$computeRegionIndex = $computeRegionNames.length - 1
$moduleName = "05 - Image Registry"
$resourceGroupNameSuffix = ".Registry"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { throw }

$templateFile = "$templateDirectory/$moduleDirectory/05-Image.Registry.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/05-Image.Registry.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { throw }

$imageRegistry = $groupDeployment.properties.outputs.imageRegistry.value
$imageRegistry | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

$sharedServices = New-Object PSObject
$sharedServices | Add-Member -MemberType NoteProperty -Name "computeNetworks" -Value $computeNetworks
$sharedServices | Add-Member -MemberType NoteProperty -Name "userIdentity" -Value $userIdentity
$sharedServices | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
$sharedServices | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
$sharedServices | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
$sharedServices | Add-Member -MemberType NoteProperty -Name "cacheMounts" -Value $cacheMounts
$sharedServices | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
$sharedServices | Add-Member -MemberType NoteProperty -Name "imageRegistry" -Value $imageRegistry

Write-Output -InputObject $sharedServices -NoEnumerate
