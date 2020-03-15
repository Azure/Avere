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

function New-SharedServices ($networkOnly, $computeNetworks) {
	if (!$networkOnly) {
		# * - Image Gallery Job
		$moduleName = "* - Image Gallery Job"
		New-TraceMessage $moduleName $true
		$imageGalleryJob = Start-Job -FilePath "$templateDirectory\Deploy.ImageGallery.ps1" -ArgumentList $resourceGroupNamePrefix, $computeRegionNames
	}

	if (!$computeNetworks || $computeNetworks.length -eq 0) {
		# 00 - Network
		$computeNetworks = @()
		$moduleName = "00 - Network"
		New-TraceMessage $moduleName $true
		for ($computeRegionIndex = 0; $computeRegionIndex -lt $computeRegionNames.length; $computeRegionIndex++) {
			New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
			$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Network"
			$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
			if (!$resourceGroup) { return }

			$templateResources = "$templateDirectory\00-Network.json"
			$templateParameters = "$templateDirectory\00-Network.Parameters.Region$computeRegionIndex.json"
			$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
			if (!$groupDeployment) { return }

			$computeNetwork = New-Object PSObject
			$computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
			$computeNetwork | Add-Member -MemberType NoteProperty -Name "name" -Value $groupDeployment.properties.outputs.virtualNetworkName.value
			$computeNetwork | Add-Member -MemberType NoteProperty -Name "domainName" -Value $groupDeployment.properties.outputs.virtualNetworkDomainName.value
			$computeNetworks += $computeNetwork
			New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]
		}
		New-TraceMessage $moduleName $false
	}

	if (!$networkOnly) {
		# 02 - Security
		$computeRegionIndex = 0
		$moduleName = "02 - Security"
		New-TraceMessage $moduleName $true $computeRegionNames[$computeRegionIndex]
		$resourceGroupName = Get-ResourceGroupName $computeRegionNames $computeRegionIndex $resourceGroupNamePrefix "Security"
		$resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionNames[$computeRegionIndex]
		if (!$resourceGroup) { return }

		$templateResources = "$templateDirectory\02-Security.json"
		$templateParameters = (Get-Content "$templateDirectory\02-Security.Parameters.json" -Raw | ConvertFrom-Json).parameters
		if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
			$templateParameters.virtualNetwork.value.resourceGroupName = $computeNetworks[$computeRegionIndex].resourceGroupName
		}
		if ($templateParameters.virtualNetwork.value.name -eq "") {
			$templateParameters.virtualNetwork.value.name = $computeNetworks[$computeRegionIndex].name
		}
		$templateParameters = ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
		$groupDeployment = az deployment group create --resource-group $resourceGroupName --template-file $templateResources --parameters $templateParameters | ConvertFrom-Json
		if (!$groupDeployment) { return }

		$logAnalyticsWorkspaceId = $groupDeployment.properties.outputs.logAnalyticsWorkspaceId.value
		$logAnalyticsWorkspaceKey = $groupDeployment.properties.outputs.logAnalyticsWorkspaceKey.value
		New-TraceMessage $moduleName $false $computeRegionNames[$computeRegionIndex]

		# * - Image Gallery Job
		$moduleName = "* - Image Gallery Job"
		$imageGallery = Receive-Job -InstanceId $imageGalleryJob.InstanceId -Wait
		New-TraceMessage $moduleName $false
	}

	$logAnalytics = New-Object PSObject
	$logAnalytics | Add-Member -MemberType NoteProperty -Name "workspaceId" -Value $logAnalyticsWorkspaceId
	$logAnalytics | Add-Member -MemberType NoteProperty -Name "workspaceKey" -Value $logAnalyticsWorkspaceKey

	$sharedServices = New-Object PSObject
	$sharedServices | Add-Member -MemberType NoteProperty -Name "computeNetworks" -Value $computeNetworks
	$sharedServices | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
	$sharedServices | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics

	return $sharedServices
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

function Get-ImageVersionId ($imageGalleryResourceGroupName, $imageGalleryName, $imageDefinitionName, $imageTemplateName) {
	$imageVersions = az sig image-version list --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName | ConvertFrom-Json
	foreach ($imageVersion in $imageVersions) {
		if ($imageVersion.tags.imageTemplate -eq $imageTemplateName) {
			return $imageVersion.id
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
