# Before running this Azure resource deployment script, make sure that the Azure CLI is installed locally.
# You must have version 2.0.76 (or greater) of the Azure CLI installed for this script to run properly.
# The current Azure CLI release is available at http://docs.microsoft.com/cli/azure/install-azure-cli

param (
	# Set a naming prefix for new Azure resource groups created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Artist.Anywhere",

	# Set to an Azure region location for compute (http://azure.microsoft.com/global-infrastructure/locations)
	[string] $regionLocationCompute = "West US 2",

	# Set to "" to skip Azure storage deployment (for example, if you are planning to use an on-premises storage system)
	[string] $regionLocationStorage = "West US 2",

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageDeployNetApp = $false,

	# Set to true to deploy Azure Blob Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageDeployBlob = $false,

	# Set to the Azure resource group name for the Azure Networking resources for compute
	[string] $computeNetworkResourceGroupName,

	# Set to the Azure resource name for the Azure Virtual Network resource for compute
	[string] $computeNetworkName,

	# Set to the Azure resource name for the Azure Private DNS Zone resource
	[string] $privateDomainName
)

$templateRootDirectory = $PSScriptRoot
if (!$templateRootDirectory) {
	$templateRootDirectory = $using:templateRootDirectory
}

Import-Module "$templateRootDirectory\Deploy.psm1"

# 00 - Network
if (!$computeNetworkResourceGroupName -or !$computeNetworkName) {
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (00 - Network Deployment Start)")
	$resourceGroupName = "$resourceGroupNamePrefix-Network"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
	if (!$resourceGroup) { return }

	$templateResources = "$templateRootDirectory\00-Network.json"
	$templateParameters = "$templateRootDirectory\00-Network.Parameters.json"
	$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$computeNetworkResourceGroupName = $resourceGroupName
	$computeNetworkName = $groupDeployment.properties.outputs.virtualNetworkName.value
	$privateDomainName = $groupDeployment.properties.outputs.virtualNetworkPrivateDomainName.value
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (00 - Network Deployment End)")
}

$templateRootDirectory = $templateRootDirectory + "\StorageCache"

# 03.0 - Storage
$storageTargets = @()
if ($regionLocationStorage -ne "") {
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (03.0 - Storage Deployment Start)")
	$resourceGroupName = "$resourceGroupNamePrefix-Storage"
	$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationStorage
	if (!$resourceGroup) { return }

	if ($storageDeployBlob) {
		$templateResources = "$templateRootDirectory\03-Storage.Blob.json"
		$templateParameters = "$templateRootDirectory\03-Storage.Blob.Parameters.json"

		$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
		if (!$groupDeployment) { return }

		$storageNetworkName = $groupDeployment.properties.outputs.virtualNetworkName.value
		$storageTargets = $groupDeployment.properties.outputs.storageTargets.value

		if ($storageNetworkName -ne "" -and $storageNetworkName -ne $computeNetworkName) {
			$storageNetworkId = az network vnet show --resource-group $resourceGroupName --name $storageNetworkName --query id
			$networkPeering = Set-NetworkPeering $resourceGroupName $storageNetworkName $storageNetworkId "Blob"
			if (!$networkPeering) { return }
		}
	}

	if ($storageDeployNetApp) {
		$templateResources = "$templateRootDirectory\03-Storage.NetApp.json"
		$templateParameters = "$templateRootDirectory\03-Storage.NetApp.Parameters.json"

		$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
		if (!$groupDeployment) { return }

		$storageNetworkName = $groupDeployment.properties.outputs.virtualNetworkName.value
		$storageVolumes = $groupDeployment.properties.outputs.storageTargets.value

		$netAppStorageTargets = @()
		foreach ($storageVolume in $storageVolumes) {
			$storageTargetIndex = -1
			for ($i = 0; $i -lt $netAppStorageTargets.length; $i++) {
				if ($netAppStorageTargets[$i].host -eq $storageVolume.host) {
					$storageTargetIndex = $i
				}
			}
			if ($storageTargetIndex -gt -1) {
				$netAppStorageTargets[$storageTargetIndex].junctions = $netAppStorageTargets[$storageTargetIndex].junctions + $storageVolume.junctions
			} else {
				$netAppStorageTargets = $netAppStorageTargets + $storageVolume
			}
		}

		$storageTargets = $storageTargets + $netAppStorageTargets

		if ($storageNetworkName -ne "" -and $storageNetworkName -ne $computeNetworkName) {
			$storageNetworkId = az network vnet show --resource-group $resourceGroupName --name $storageNetworkName --query id
			$networkPeering = Set-NetworkPeering $resourceGroupName $storageNetworkName $storageNetworkId "NetApp"
			if (!$networkPeering) { return }
		}
	}
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (03.0 - Storage Deployment End)")
}

# 04.0 - Cache
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (04.0 - Cache Deployment Start)")
$resourceGroupName = "$resourceGroupNamePrefix-Cache"
$resourceGroup = az group create --resource-group $resourceGroupName --location $regionLocationCompute
if (!$resourceGroup) { return }

$templateResources = "$templateRootDirectory\04-Cache.json"
$templateParameters = (Get-Content "$templateRootDirectory\04-Cache.Parameters.json" -Raw | ConvertFrom-Json).parameters
if ($templateParameters.storageTargets.value.length -gt 0 -and $templateParameters.storageTargets.value[0].name -ne "") {
	$templateParameters.storageTargets.value = $templateParameters.storageTargets.value + $storageTargets
} else {
	$templateParameters.storageTargets.value = $storageTargets
}
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $computeNetworkResourceGroupName
$templateParameters | Add-Member -MemberType NoteProperty -Name "virtualNetworkResourceGroupName" -Value $templateParameter -Force
$templateParameter = New-Object PSObject
$templateParameter | Add-Member -MemberType NoteProperty -Name "value" -Value $computeNetworkName
$templateParameters | Add-Member -MemberType NoteProperty -Name "virtualNetworkName" -Value $templateParameter -Force
$templateParameters = ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
$groupDeployment = (az group deployment create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$cacheSubnetName = $groupDeployment.properties.outputs.cacheSubnetName.value
$cacheMountAddresses = $groupDeployment.properties.outputs.cacheMountAddresses.value
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (04.0 - Cache Deployment End)")

# 04.1 - Cache DNS
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (04.1 - Cache DNS Record Set Start)")
$cacheSubdomainName = $cacheSubnetName.ToLower()
az network private-dns record-set a delete --resource-group $computeNetworkResourceGroupName --zone-name $privateDomainName --name $cacheSubdomainName --yes
foreach ($cacheMountAddress in $cacheMountAddresses) {
	$cacheMountRecord = az network private-dns record-set a add-record --resource-group $computeNetworkResourceGroupName --zone-name $privateDomainName --record-set-name $cacheSubdomainName --ipv4-address $cacheMountAddress
	if (!$cacheMountRecord) { return }
}
$cacheDomainRecord = (az network private-dns record-set a show --resource-group $computeNetworkResourceGroupName --zone-name $privateDomainName --name $cacheSubdomainName) | ConvertFrom-Json
if (!$cacheDomainRecord) { return }
$cacheMountHost = $cacheDomainRecord.fqdn
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (04.1 - Cache DNS Record Set End)")

# 04.2 - Storage Mounts
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (04.2 - Storage Mounts Start)")
$storageMounts = ""; $outerDelimiter = "|"; $innerDelimiter = ";"
$storageMountOptions = ",hard,proto=tcp,mountproto=tcp,retry=30"
foreach ($storageTarget in $storageTargets) {
	if ($storageTarget.junctions.length -eq 0) {
		if ($storageMounts -ne "") {
			$storageMounts = $storageMounts + $outerDelimiter
		}
		$storageMounts = $storageMounts + $storageTarget.namespacePath + $innerDelimiter
		$storageMounts = $storageMounts + $storageTarget.mountOptions + $storageMountOptions + $innerDelimiter
		$storageMounts = $storageMounts + $storageTarget.host + ":" + $storageTarget.namespacePath
	} else {
		foreach ($storageTargetJunction in $storageTarget.junctions) {
			if ($storageMounts -ne "") {
				$storageMounts = $storageMounts + $outerDelimiter
			}
			$storageMounts = $storageMounts + $storageTargetJunction.namespacePath + $innerDelimiter
			$storageMounts = $storageMounts + $storageTarget.mountOptions + $storageMountOptions + $innerDelimiter
			$storageMounts = $storageMounts + $cacheMountHost + ":" + $storageTargetJunction.namespacePath
		}
	}
}
Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (04.2 - Storage Mounts End)")

Write-Output -InputObject $storageMounts