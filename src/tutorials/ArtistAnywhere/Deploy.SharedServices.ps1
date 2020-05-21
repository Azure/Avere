param (
	# Set a naming prefix for the Azure resource groups that are created by this deployment script
	[string] $resourceGroupNamePrefix = "Azure.Media.Studio",

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $computeRegionNames = @("WestUS2"),

	# Set to 1 or more Azure region names (http://azure.microsoft.com/global-infrastructure/regions)
	[string[]] $storageRegionNames = @("WestUS2"),

	# Set to true to deploy Azure NetApp Files (http://docs.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction)
	[boolean] $storageNetAppEnable = $false,

	# Set to true to deploy Azure Object (Blob) Storage (http://docs.microsoft.com/azure/storage/blobs/storage-blobs-overview)
	[boolean] $storageObjectEnable = $false,

	# Set to true to deploy Azure HPC Cache (https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-overview)
	[boolean] $cacheEnable = $false
)

$templateDirectory = $PSScriptRoot
if (!$templateDirectory) {
	$templateDirectory = $using:templateDirectory
}

Import-Module "$templateDirectory/Deploy.psm1"

# 00 - Network
$computeNetworks = @()
$moduleName = "00 - Network"
$resourceGroupNameSuffix = "Network"
New-TraceMessage $moduleName $false
for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
	$computeRegionName = $computeRegionNames[$computeRegionIndex]
	New-TraceMessage $moduleName $false $computeRegionName
	$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionIndex
	$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName
	if (!$resourceGroup) { return }

	$templateResources = "$templateDirectory/00-Network.json"
	$templateParameters = "$templateDirectory/00-Network.Parameters.$computeRegionName.json"

	$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
	if (!$groupDeployment) { return }

	$computeNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
	$computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
	$computeNetworks += $computeNetwork
	New-TraceMessage $moduleName $true $computeRegionName
}
New-TraceMessage $moduleName $true

# 01 - Access Control
$computeRegionIndex = 0
$moduleName = "01 - Access Control"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory/01-Access.Control.json"
$templateParameters = (Get-Content "$templateDirectory/01-Access.Control.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.virtualNetwork.value.name -eq "") {
	$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
	$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$managedIdentity = $groupDeployment.properties.outputs.managedIdentity.value
$keyVault = $groupDeployment.properties.outputs.keyVault.value
$logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

# 02 - Image Gallery
$computeRegionIndex = 0
$moduleName = "02 - Image Gallery"
$resourceGroupNameSuffix = "Image"
New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix
$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
if (!$resourceGroup) { return }

$templateResources = "$templateDirectory/02-Image.Gallery.json"
$templateParameters = (Get-Content "$templateDirectory/02-Image.Gallery.Parameters.json" -Raw | ConvertFrom-Json).parameters

if ($templateParameters.imageBuilder.value.userPrincipalId -eq "") {
	$templateParameters.imageBuilder.value.userPrincipalId = $managedIdentity.userPrincipalId
}
if ($templateParameters.virtualNetwork.value.name -eq "") {
	$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
}
if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
	$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
}

$templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
if (!$groupDeployment) { return }

$imageGallery = $groupDeployment.properties.outputs.imageGallery.value
$imageGallery | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]

$moduleDirectory = "StorageCache"

# 03 - Storage
$storageMounts = @()
$storageTargets = @()
if ($storageNetAppEnable -or $storageObjectEnable) {
	$moduleName = "03 - Storage"
	$resourceGroupNameSuffix = "Storage"
	New-TraceMessage $moduleName $false
	for ($storageRegionIndex = 0; $storageRegionIndex -lt $storageRegionNames.length; $storageRegionIndex++) {
		$storageRegionName = $storageRegionNames[$storageRegionIndex]
		New-TraceMessage $moduleName $false $storageRegionName
		$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionIndex
		$resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName
		if (!$resourceGroup) { return }

		$storageMountsNetApp = @()
		$storageTargetsNetApp = @()
		if ($storageNetAppEnable) {
			$templateResources = "$templateDirectory/$moduleDirectory/03-Storage.NetApp.json"
			$templateParameters = "$templateDirectory/$moduleDirectory/03-Storage.NetApp.Parameters.$storageRegionName.json"
			
			$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
			if (!$groupDeployment) { return }

			$storageNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
			$storageAccount = $groupDeployment.properties.outputs.storageAccount.value
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
					$storageTargetsNetApp[$storageTargetIndex].name = $storageNetwork.name + ".NetApp"
					$storageTargetsNetApp[$storageTargetIndex].junctions += $storageTargetTemp.junctions
				} else {
					$storageTargetsNetApp += $storageTargetTemp
				}
			}

			$subModuleName = $moduleName + " (NetApp)"
			$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
			$networkPeering = New-NetworkPeering $computeRegionNames $computeNetworks $storageNetwork $subModuleName
			if (!$networkPeering) { return }

			$dnsRecordName = $storageAccount.subnetName.ToLower() + ".storage"
			foreach ($storageMountNetApp in $storageMountsNetApp) {
				$dnsRecordIpAddress = $storageMountNetApp.exportHost
				az network private-dns record-set a delete --resource-group $computeNetworks[$storageRegionIndex].resourceGroupName --zone-name $computeNetworks[$storageRegionIndex].domainName --name $dnsRecordName --yes
				$dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetworks[$storageRegionIndex].resourceGroupName --zone-name $computeNetworks[$storageRegionIndex].domainName --record-set-name $dnsRecordName --ipv4-address $dnsRecordIpAddress) | ConvertFrom-Json
				if (!$dnsRecord) { return }
				$storageMountNetApp.exportHost = $dnsRecord.fqdn
			}
		}

		$storageMountsObject = @()
		$storageTargetsObject = @()
		if ($storageObjectEnable) {
			$templateResources = "$templateDirectory/$moduleDirectory/03-Storage.Object.json"
			$templateParameters = "$templateDirectory/$moduleDirectory/03-Storage.Object.Parameters.$storageRegionName.json"
			
			$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters) | ConvertFrom-Json
			if (!$groupDeployment) { return }

			$storageNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
			$storageAccount = $groupDeployment.properties.outputs.storageAccount.value
			$storageMountsObject = $groupDeployment.properties.outputs.storageMounts.value
			$storageTargetsObject = $groupDeployment.properties.outputs.storageTargets.value

			$subModuleName = $moduleName + " (Object)"
			$storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
			$networkPeering = New-NetworkPeering $computeRegionNames $computeNetworks $storageNetwork $subModuleName
			if (!$networkPeering) { return }
		}

		$storageMounts += $storageMountsNetApp + $storageMountsObject
		$storageTargets += $storageTargetsNetApp + $storageTargetsObject

		New-TraceMessage $moduleName $true $storageRegionName
	}
	New-TraceMessage $moduleName $true
}

# 04 - Cache
$cacheMounts = @()
if ($cacheEnable) {
	$moduleName = "04 - Cache"
	$resourceGroupNameSuffix = "Cache"
	New-TraceMessage $moduleName $false
	for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
		$computeRegionName = $computeRegionNames[$computeRegionIndex]
		New-TraceMessage $moduleName $false $computeRegionName
		$resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionIndex
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

$sharedServices = New-Object PSObject
$sharedServices | Add-Member -MemberType NoteProperty -Name "computeNetworks" -Value $computeNetworks
$sharedServices | Add-Member -MemberType NoteProperty -Name "managedIdentity" -Value $managedIdentity
$sharedServices | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
$sharedServices | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
$sharedServices | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
$sharedServices | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
$sharedServices | Add-Member -MemberType NoteProperty -Name "cacheMounts" -Value $cacheMounts

Write-Output -InputObject $sharedServices -NoEnumerate
