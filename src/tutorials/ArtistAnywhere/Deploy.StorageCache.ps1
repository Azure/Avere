param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name for Compute resources (e.g., Shared Image Gallery, Container Registry, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for Storage resources (e.g., Virtual Network, Object (Blob) Storage, NetApp Files, etc.)
    [string] $storageRegionName = "EastUS2",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false,

    # The shared Azure solution services (e.g., Virtual Networks, Managed Identity, Log Analytics, etc.)
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
    $sharedServicesJob = Start-Job -FilePath "$templateDirectory/Deploy.SharedServices.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionName
    $sharedServices = Receive-Job -Job $sharedServicesJob -Wait
    New-TraceMessage $moduleName $true
}
$computeNetwork = $sharedServices.computeNetwork

$moduleDirectory = "StorageCache"

# 04 - Storage Network
$moduleName = "04 - Storage Network"
$resourceGroupNameSuffix = ".Network"
New-TraceMessage $moduleName $false $storageRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName

$templateFile = "$templateDirectory/$moduleDirectory/04-Storage.Network.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Storage.Network.Parameters.json" -Raw | ConvertFrom-Json).parameters

$templateParameters.computeNetwork.value = $computeNetwork

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 8).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

$storageNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $storageRegionName

$storageMounts = @()
$storageTargets = @()

# 04 - Storage (Object)
$moduleName = "04 - Storage (Object)"
$resourceGroupNameSuffix = ".Storage.Object"
New-TraceMessage $moduleName $false $storageRegionName
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
$resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName

$templateFile = "$templateDirectory/$moduleDirectory/04-Storage.Object.json"
$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Storage.Object.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
    $templateParameters.virtualNetwork.value.name = $storageNetwork.name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
    $templateParameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

# $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
# $storageTargets += $groupDeployment.properties.outputs.storageTargets.value
New-TraceMessage $moduleName $true $storageRegionName

# 04 - Storage (NetApp)
if ($storageNetAppEnable) {
    $storageMountsNetApp = @()
    $storageTargetsNetApp = @()
    $moduleName = "04 - Storage (NetApp)"
    $resourceGroupNameSuffix = ".Storage.NetApp"
    New-TraceMessage $moduleName $false $storageRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/04-Storage.NetApp.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Storage.NetApp.Parameters.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $storageNetwork.name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

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
    New-TraceMessage $moduleName $true $storageRegionName
}

# 05 - Cache
$cacheMounts = @()
if ($storageCacheEnable) {
    $moduleName = "05 - Cache"
    $resourceGroupNameSuffix = ".Cache"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/05-Cache.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/05-Cache.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.storageTargets.value.length -gt 0 -and $templateParameters.storageTargets.value[0].name -ne "") {
        $templateParameters.storageTargets.value += $storageTargets
    } else {
        $templateParameters.storageTargets.value = $storageTargets
    }
    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $computeNetwork.name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $dnsRecordName = $groupDeployment.properties.outputs.virtualNetwork.value.subnetName.ToLower()
    az network private-dns record-set a delete --resource-group $computeNetwork.resourceGroupName --zone-name $computeNetwork.domainName --name $dnsRecordName --yes
    foreach ($cacheMountAddress in $groupDeployment.properties.outputs.mountAddresses.value) {
        $dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetwork.resourceGroupName --zone-name $computeNetwork.domainName --record-set-name $dnsRecordName --ipv4-address $cacheMountAddress) | ConvertFrom-Json
    }

    foreach ($cacheTarget in $groupDeployment.properties.outputs.storageTargets.value) {
        foreach ($cacheTargetJunction in $cacheTarget.junctions) {
            $cacheMount = New-Object PSObject
            $cacheMount | Add-Member -MemberType NoteProperty -Name "exportHost" -Value $dnsRecord.fqdn
            $cacheMount | Add-Member -MemberType NoteProperty -Name "exportPath" -Value $cacheTargetJunction.namespacePath
            $cacheMount | Add-Member -MemberType NoteProperty -Name "directoryPath" -Value $cacheTargetJunction.namespacePath
            $cacheMount | Add-Member -MemberType NoteProperty -Name "fileSystemType" -Value $cacheTarget.mountType
            $cacheMount | Add-Member -MemberType NoteProperty -Name "fileSystemOptions" -Value $cacheTarget.mountOptions
            $cacheMount | Add-Member -MemberType NoteProperty -Name "fileSystemDrive" -Value $cacheTarget.mountDrive
            $cacheMounts += $cacheMount
        }
    }
    New-TraceMessage $moduleName $true $computeRegionName
}

$storageCache = New-Object PSObject
$storageCache | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
$storageCache | Add-Member -MemberType NoteProperty -Name "cacheMounts" -Value $cacheMounts

Write-Output -InputObject $storageCache -NoEnumerate
