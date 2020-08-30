param (
    # Set a naming prefix for the Azure resource groups that are created by this deployment script
    [string] $resourceGroupNamePrefix = "Azure.Media.Studio",

    # Set the Azure region name for Compute resources (e.g., Shared Image Gallery, Container Registry, etc.)
    [string] $computeRegionName = "WestUS2",

    # Set the Azure region name for Storage resources (e.g., Virtual Network, NetApp Files, Object Storage, etc.)
    [string] $storageRegionName = "EastUS",

    # Set to true to deploy Azure NetApp Files (https://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
    [boolean] $storageNetAppEnable = $false,

    # Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/azure/hpc-cache/hpc-cache-overview)
    [boolean] $storageCacheEnable = $false,

    # Set to true to deploy Azure VPN Gateway (https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
    [boolean] $vnetGatewayEnable = $false,

    # The shared Azure solution services (e.g., Virtual Networks, Managed Identity, Log Analytics, etc.)
    [object] $sharedServices
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
    $templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

if (!$sharedServices) {
    $sharedServices = Get-SharedServices $resourceGroupNamePrefix $computeRegionName $storageRegionName $storageNetAppEnable $vnetGatewayEnable
}
if (!$sharedServices.computeNetwork) {
    return
}
$computeNetwork = $sharedServices.computeNetwork

$moduleDirectory = "StorageCache"

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

$sharedServices | Add-Member -MemberType NoteProperty -Name "cacheMounts" -Value $cacheMounts

Write-Output -InputObject $sharedServices -NoEnumerate
