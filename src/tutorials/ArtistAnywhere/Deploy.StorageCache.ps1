# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.2.0 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("West US 2", "East US 2"),

	# Set to the Azure Networking resources (Virtual Network, Private DNS, etc.) for compute regions
	[object[]] $computeNetworks = @(),

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageDeployNetApp = $false,

	# Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageDeployObject = $false
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory\Deploy.psm1"

$sharedServices = New-SharedServices $true $computeNetworks
$computeNetworks = $sharedServices.computeNetworks

$moduleDirectory = "StorageCache"

# 03.0 - Storage
$storageTargetsNetApp = @()
$storageTargetsObject = @()
if ($storageDeployNetApp || $storageDeployObject) {
	$computeRegionIndex = 0
	$moduleName = "03.0 - Storage"
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Storage"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	if ($storageDeployNetApp) {
		$subModuleName = "$moduleName (NetApp)"
		New-TraceMessage $subModuleName $true $computeRegionNames[$computeRegionIndex]
		$templateResources = "$templateDirectory\$moduleDirectory\03-Storage.NetApp.json"
		$templateParameters = "$templateDirectory\$moduleDirectory\03-Storage.NetApp.Parameters.json"

		$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
		if (!$groupDeployment) { return }

		$storageNetworkName = $groupDeployment.properties.outputs.virtualNetworkName.value
		$storageTargets = $groupDeployment.properties.outputs.storageTargets.value

		foreach ($storageTarget in $storageTargets) {
			$storageTargetIndex = -1
			for ($i = 0; $i -lt $storageTargetsNetApp.length; $i++) {
				if ($storageTargetsNetApp[$i].host -eq $storageTarget.host) {
					$storageTargetIndex = $i
				}
			}
			if ($storageTargetIndex -ge 0) {
				$storageTargetsNetApp[$storageTargetIndex].name = "$storageNetworkName.NetApp"
				$storageTargetsNetApp[$storageTargetIndex].junctions += $storageTarget.junctions
			} else {
				$storageTargetsNetApp += $storageTarget
			}
		}

		$storageNetwork = New-Object PSObject
		$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
		$storageNetwork | Add-Member -MemberType NoteProperty -Name "name" -Value $storageNetworkName
		$networkPeering = New-NetworkPeering $computeRegionNames $computeNetworks $storageNetwork "NetApp"
		if (!$networkPeering) { return }
		New-TraceMessage $subModuleName $false $computeRegionNames[$computeRegionIndex]
	}

	if ($storageDeployObject) {
		$subModuleName = "$moduleName (Object)"
		New-TraceMessage $subModuleName $true $computeRegionNames[$computeRegionIndex]
		$templateResources = "$templateDirectory\$moduleDirectory\03-Storage.Object.json"
		$templateParameters = "$templateDirectory\$moduleDirectory\03-Storage.Object.Parameters.json"

		$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
		if (!$groupDeployment) { return }

		$storageNetworkName = $groupDeployment.properties.outputs.virtualNetworkName.value
		$storageTargetsObject = $groupDeployment.properties.outputs.storageTargets.value

		if ($storageNetworkName -ne "") {
			$storageNetwork = New-Object PSObject
			$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
			$storageNetwork | Add-Member -MemberType NoteProperty -Name "name" -Value $storageNetworkName
			$networkPeering = New-NetworkPeering $computeRegionNames $computeNetworks $storageNetwork "Object"
			if (!$networkPeering) { return }
		}
		New-TraceMessage $subModuleName $false $computeRegionNames[$computeRegionIndex]
	}
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}

# 04.0 - Cache
$storageCaches = @()
$moduleName = "04.0 - Cache"
New-TraceMessage $moduleName $true
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
	$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Cache"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory\$moduleDirectory\04-Cache.json"
	$templateParameters = (Get-Content "$templateDirectory\$moduleDirectory\04-Cache.Parameters.Region$computeRegionIndex.json" -Raw | ConvertFrom-Json).parameters
	if ($computeRegionIndex -eq 0) {
		$storageTargets = $storageTargetsNetApp + $storageTargetsObject
	} else {
		$storageTargets = $storageTargetsObject
	}
	if ($templateParameters.storageTargets.value.length -gt 0 && $templateParameters.storageTargets.value[0].name -ne "") {
		$templateParameters.storageTargets.value += $storageTargets
	} else {
		$templateParameters.storageTargets.value = $storageTargets
	}
	if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
		$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
	}
	if ($templateParameters.virtualNetwork.value.name -eq "") {
		$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
	}
	$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
	$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$storageCache = New-Object PSObject
	$storageCache | Add-Member -MemberType NoteProperty -Name "storageTargets" -Value $groupDeployment.properties.outputs.storageTargets.value
	$storageCache | Add-Member -MemberType NoteProperty -Name "mountAddresses" -Value $groupDeployment.properties.outputs.mountAddresses.value
	$storageCache | Add-Member -MemberType NoteProperty -Name "subnetName" -Value $groupDeployment.properties.outputs.subnetName.value
	$storageCaches += $storageCache
	New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
}
New-TraceMessage $moduleName $false

# 04.1 - Cache DNS
$moduleName = "04.1 - Cache DNS"
New-TraceMessage $moduleName $true
for ($cacheIndex = 0; $cacheIndex -lt $storageCaches.length; $cacheIndex++) {
	New-TraceMessage $moduleName $true $computeNetworks[$cacheIndex].domainName
	$cacheSubdomainName = $storageCaches[$cacheIndex].subnetName.ToLower()
	az network private-dns record-set a delete --resource-group $computeNetworks[$cacheIndex].resourceGroupName --zone-name $computeNetworks[$cacheIndex].domainName --name $cacheSubdomainName --yes

	foreach ($cacheMountAddress in $storageCaches[$cacheIndex].mountAddresses) {
		$cacheMountRecord = az network private-dns record-set a add-record --resource-group $computeNetworks[$cacheIndex].resourceGroupName --zone-name $computeNetworks[$cacheIndex].domainName --record-set-name $cacheSubdomainName --ipv4-address $cacheMountAddress
		if (!$cacheMountRecord) { return }
	}
	$cacheDomainRecord = az network private-dns record-set a show --resource-group $computeNetworks[$cacheIndex].resourceGroupName --zone-name $computeNetworks[$cacheIndex].domainName --name $cacheSubdomainName | ConvertFrom-Json
	if (!$cacheDomainRecord) { return }

	$cacheMounts = @() 
	foreach ($storageTarget in $storageCaches[$cacheIndex].storageTargets) {
		foreach ($storageTargetJunction in $storageTarget.junctions) {
			$cacheMount = New-Object PSObject
			$cacheMount | Add-Member -MemberType NoteProperty -Name "targetHost" -Value $cacheDomainRecord.fqdn
			$cacheMount | Add-Member -MemberType NoteProperty -Name "namespacePath" -Value $storageTargetJunction.namespacePath
			$cacheMount | Add-Member -MemberType NoteProperty -Name "mountOptions" -Value $storageTarget.mountOptions
			$cacheMounts += $cacheMount
		}
	}
	$storageCaches[$cacheIndex] | Add-Member -MemberType NoteProperty -Name "mounts" -Value $cacheMounts
	New-TraceMessage $moduleName $false $computeNetworks[$cacheIndex].domainName
}
New-TraceMessage $moduleName $false

Write-Output -InputObject $storageCaches -NoEnumerate
