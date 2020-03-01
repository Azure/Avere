function New-TraceMessage ($moduleName, $moduleStart, $regionName) {
	$traceMessage = [System.DateTime]::Now.ToLongTimeString()
	if ($regionName) {
		$traceMessage += " @ " + $regionName
	}
	$traceMessage += " ($moduleName "
	if ($moduleName.Substring(0, 1) -ne "*") {
		$traceMessage += "Deployment "
	}
	if ($moduleStart) {
		$traceMessage += "Start)"
	} else {
		$traceMessage += "End)"
	}
	Write-Host $traceMessage
}

function New-NetworkPeering ([string[]] $computeRegionNames, [object[]] $computeNetworks, $storageNetwork, $storageType) {
	$moduleName = "03.1 - $storageType Storage Network Peering"
	New-TraceMessage $moduleName $true
	$storageNetworkId = az network vnet show --resource-group $storageNetwork.resourceGroupName --name $storageNetwork.name --query id
	for ($computeNetworkIndex = 0; $computeNetworkIndex -lt $computeNetworks.length; $computeNetworkIndex++) {
		New-TraceMessage $moduleName $true $computeRegionNames[$computeNetworkIndex]
		$computeNetworkResourceGroupName = $computeNetworks[$computeNetworkIndex].resourceGroupName
		$computeNetworkName = $computeNetworks[$computeNetworkIndex].name
		$networkPeering = az network vnet peering create --resource-group $computeNetworkResourceGroupName --vnet-name $computeNetworkName --name $storageNetwork.name --remote-vnet $storageNetworkId --allow-vnet-access
		if (!$networkPeering) { return }
		$computeNetworkId = az network vnet show --resource-group $computeNetworkResourceGroupName --name $computeNetworkName --query id
		$networkPeering = az network vnet peering create --resource-group $storageNetwork.resourceGroupName --vnet-name $storageNetwork.name --name $computeNetworkName --remote-vnet $computeNetworkId --allow-vnet-access
		if (!$networkPeering) { return }
		New-TraceMessage $moduleName $false $computeRegionNames[$computeNetworkIndex]
	}
	New-TraceMessage $moduleName $false
	return $networkPeering
}

function Get-RegionNames ([string[]] $regionDisplayNames) {
	$regionNames = @()
	$regionLocations = az account list-locations | ConvertFrom-Json
	foreach ($regionDisplayName in $regionDisplayNames) {
		foreach ($regionLocation in $regionLocations) {
			if ($regionLocation.displayName -eq $regionDisplayName) {
				$regionNames += $regionLocation.name
			}
		}
	}
	return $regionNames
}

function Get-ResourceGroupName ([string[]] $computeRegionNames, $computeRegionIndex, $resourceGroupNamePrefix, $resourceGroupNameSuffix) {
	$resourceGroupName = $resourceGroupNamePrefix
	if ($computeRegionNames.length -gt 1) {
		$resourceGroupName = "$resourceGroupName$computeRegionIndex"
	}
	return "$resourceGroupName-$resourceGroupNameSuffix"
}

function Get-ImageDefinition ($imageGallery, $imageDefinitionName) {
	foreach ($imageDefinition in $imageGallery.imageDefinitions) {
		if ($imageDefinition.name -eq $imageDefinitionName) {
			return $imageDefinition
		}
	}
}

function Get-ImageVersion ($imageGalleryResourceGroupName, $imageGalleryName, $imageDefinitionName, $imageTemplateName) {
	$imageVersions = az sig image-version list --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName | ConvertFrom-Json
	foreach ($imageVersion in $imageVersions) {
		if ($imageVersion.tags.imageTemplate -eq $imageTemplateName) {
			return $imageVersion
		}
	}
}

function Get-CacheMounts ($storageCache) {
	$cacheMounts = ""
	foreach ($storageCacheMount in $storageCache.mounts) {
		if ($cacheMounts -ne "") {
			$cacheMounts += "|"
		}
		$cacheMount = $storageCacheMount.targetHost + ":" + $storageCacheMount.namespacePath
		$cacheMount += " " + $storageCacheMount.namespacePath
		$cacheMount += " " + $storageCacheMount.mountOptions
		$cacheMounts += $cacheMount
	}
	$memoryStream = New-Object System.IO.MemoryStream
	$streamWriter = New-Object System.IO.StreamWriter($memoryStream)
	$streamWriter.Write($cacheMounts)
	$streamWriter.Close();
	return [System.Convert]::ToBase64String($memoryStream.ToArray())	
}

function Get-MachineExtensionScript ($scriptFilePath, $scriptParameters) {
	$machineExtensionScript = Get-Content $scriptFilePath -Raw
	if ($scriptParameters) {
		$machineExtensionScript = "& {" + $machineExtensionScript + "} " + $scriptParameters
		$machineExtensionScriptBytes = [System.Text.Encoding]::Unicode.GetBytes($machineExtensionScript)
	} else {
		$memoryStream = New-Object System.IO.MemoryStream
		$compressionStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
		$streamWriter = New-Object System.IO.StreamWriter($compressionStream)
		$streamWriter.Write($machineExtensionScript)
		$streamWriter.Close();
		$machineExtensionScriptBytes = $memoryStream.ToArray()	
	}
	return [Convert]::ToBase64String($machineExtensionScriptBytes)
}
