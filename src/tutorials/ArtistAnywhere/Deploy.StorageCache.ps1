param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("WestUS2"),

	# Set to the Azure Networking resources (Virtual Network, Private DNS, etc.) for compute regions
	[object[]] $computeNetworks = @(),

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $storageRegionNames = @("WestUS2"),

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageDeployNetApp = $false,

	# Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageDeployObject = $false
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

$networkOnly = $true
$sharedServices = New-SharedServices $resourceGroupNamePrefix $templateDirectory $networkOnly $computeRegionNames $computeNetworks
$computeNetworks = $sharedServices.computeNetworks

$moduleDirectory = "StorageCache"

# 03.0 - Storage (NetApp)
$storageMountsNetApp = @()
$storageTargetsNetApp = @()
if ($storageDeployNetApp) {
	$moduleName = "03.0 - Storage (NetApp)"
	New-TraceMessage $moduleName $false
	for ($storageRegionIndex = 0; $storageRegionIndex -lt $storageRegionNames.length; $storageRegionIndex++) {
		$storageRegionName = $storageRegionNames[$storageRegionIndex]
		New-TraceMessage $moduleName $false $storageRegionName
		$resourceGroupName = Get-ResourceGroupName $storageRegionIndex $resourceGroupNamePrefix "Storage"
		$resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName
		if (!$resourceGroup) { return }
	
		$templateResources = "$templateDirectory/$moduleDirectory/03-Storage.NetApp.json"
		$templateParameters = "$templateDirectory/$moduleDirectory/03-Storage.NetApp.Parameters.$storageRegionName.json"

		$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
		if (!$groupDeployment) { return }
	
		$storageNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
		$storageAccount = $groupDeployment.properties.outputs.storageAccount.value
		$storageMountsNetApp = $groupDeployment.properties.outputs.storageMounts.value
		$storageTargets = $groupDeployment.properties.outputs.storageTargets.value
	
		foreach ($storageTarget in $storageTargets) {
			$storageTargetIndex = -1
			for ($i = 0; $i -lt $storageTargetsNetApp.length; $i++) {
				if ($storageTargetsNetApp[$i].host -eq $storageTarget.host) {
					$storageTargetIndex = $i
				}
			}
			if ($storageTargetIndex -ge 0) {
				$storageTargetsNetApp[$storageTargetIndex].name = $storageNetwork.name + ".NetApp"
				$storageTargetsNetApp[$storageTargetIndex].junctions += $storageTarget.junctions
			} else {
				$storageTargetsNetApp += $storageTarget
			}
		}
	
		$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
		$networkPeering = New-NetworkPeering $computeRegionNames $computeNetworks $storageNetwork $moduleName
		if (!$networkPeering) { return }

		$dnsRecordName = $storageAccount.subnetName.ToLower() + ".storage"
		foreach ($storageMountNetApp in $storageMountsNetApp) {
			$dnsRecordIpAddress = $storageMountNetApp.exportHost
			az network private-dns record-set a delete --resource-group $computeNetworks[$storageRegionIndex].resourceGroupName --zone-name $computeNetworks[$storageRegionIndex].domainName --name $dnsRecordName --yes
			$dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetworks[$storageRegionIndex].resourceGroupName --zone-name $computeNetworks[$storageRegionIndex].domainName --record-set-name $dnsRecordName --ipv4-address $dnsRecordIpAddress) | ConvertFrom-Json
			if (!$dnsRecord) { return }
			$storageMountNetApp.exportHost = $dnsRecord.fqdn
		}
		New-TraceMessage $moduleName $true $storageRegionName
	}
	New-TraceMessage $moduleName $true
}

# 03.1 - Storage (Object)
$storageMountsObject = @()
$storageTargetsObject = @()
if ($storageDeployObject) {
	$moduleName = "03.1 - Storage (Object)"
	New-TraceMessage $moduleName $false
	for ($storageRegionIndex = 0; $storageRegionIndex -lt $storageRegionNames.length; $storageRegionIndex++) {
		$storageRegionName = $storageRegionNames[$storageRegionIndex]
		New-TraceMessage $moduleName $false $storageRegionName
		$resourceGroupName = Get-ResourceGroupName $storageRegionIndex $resourceGroupNamePrefix "Storage"
		$resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName
		if (!$resourceGroup) { return }
	
		$templateResources = "$templateDirectory/$moduleDirectory/03-Storage.Object.json"
		$templateParameters = "$templateDirectory/$moduleDirectory/03-Storage.Object.Parameters.$storageRegionName.json"

		$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
		if (!$groupDeployment) { return }
	
		$storageNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
		$storageAccount = $groupDeployment.properties.outputs.storageAccount.value
		$storageMountsObject = $groupDeployment.properties.outputs.storageMounts.value
		$storageTargetsObject = $groupDeployment.properties.outputs.storageTargets.value
	
		$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
		$networkPeering = New-NetworkPeering $computeRegionNames $computeNetworks $storageNetwork $moduleName
		if (!$networkPeering) { return }
		New-TraceMessage $moduleName $true $storageRegionName
	}
	New-TraceMessage $moduleName $true
}

$storageMounts = $storageMountsNetApp + $storageMountsObject
$storageTargets = $storageTargetsNetApp + $storageTargetsObject

# 04.0 - Cache
$storageCaches = @()
$moduleName = "04.0 - Cache"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	$computeRegionName = $computeRegionNames[$computeRegionIndex]
	New-TraceMessage $moduleName $false $computeRegionName
	$resourceGroupName = Get-ResourceGroupName $computeRegionIndex $resourceGroupNamePrefix "Cache"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory/$moduleDirectory/04-Cache.json"
	$templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Cache.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters
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
	$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$dnsRecordName = $groupDeployment.properties.outputs.virtualNetwork.value.subnetName.ToLower()
	az network private-dns record-set a delete --resource-group $computeNetworks[$computeRegionIndex].resourceGroupName --zone-name $computeNetworks[$computeRegionIndex].domainName --name $dnsRecordName --yes
	foreach ($cacheMountAddress in $groupDeployment.properties.outputs.mountAddresses.value) {
		$dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetworks[$computeRegionIndex].resourceGroupName --zone-name $computeNetworks[$computeRegionIndex].domainName --record-set-name $dnsRecordName --ipv4-address $cacheMountAddress) | ConvertFrom-Json
		if (!$dnsRecord) { return }
	}

	$cacheMounts = @()
	foreach ($cacheTarget in $groupDeployment.properties.outputs.storageTargets.value) {
		foreach ($cacheTargetJunction in $cacheTarget.junctions) {
			$cacheMount = New-Object PSObject
			$cacheMount | Add-Member -MemberType NoteProperty -Name "exportHost" -Value $dnsRecord.fqdn
			$cacheMount | Add-Member -MemberType NoteProperty -Name "exportPath" -Value $cacheTargetJunction.namespacePath
			$cacheMount | Add-Member -MemberType NoteProperty -Name "directory" -Value $cacheTargetJunction.namespacePath
			$cacheMount | Add-Member -MemberType NoteProperty -Name "options" -Value $cacheTarget.mountOptions
			$cacheMounts += $cacheMount
		}
	}

	$storageCache = $storageMounts + $cacheMounts
	$storageCaches += $storageCache
	New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

Write-Output -InputObject $storageCaches -NoEnumerate
