function Set-NetworkPeering ($storageNetworkResourceGroupName, $storageNetworkName, $storageNetworkId, $storageType) {
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (03.1 - Storage (" + $storageType + ") Network Peering Start)")
	$networkPeeringName = $storageNetworkName
	$networkPeering = az network vnet peering create --resource-group $computeNetworkResourceGroupName --vnet-name $computeNetworkName --name $networkPeeringName --remote-vnet $storageNetworkId --allow-vnet-access
	if (!$networkPeering) { return }
	$computeNetworkId = az network vnet show --resource-group $computeNetworkResourceGroupName --name $computeNetworkName --query id
	$networkPeeringName = $computeNetworkName
	$networkPeering = az network vnet peering create --resource-group $storageNetworkResourceGroupName --vnet-name $storageNetworkName --name $networkPeeringName --remote-vnet $computeNetworkId --allow-vnet-access
	if (!$networkPeering) { return }
	Write-Host ([System.DateTime]::Now.ToLongTimeString() + " (03.1 - Storage (" + $storageType + ") Network Peering End)")
	return $networkPeering
}

function Get-ImageDefinition ($imageDefinitionName, $imageDefinitions) {
	foreach ($imageDefinition in $imageDefinitions) {
		if ($imageDefinition.name -eq $imageDefinitionName) {
			return $imageDefinition
		}
	}
}

function Get-ImageVersion ($resourceGroupName, $imageGalleryName, $imageDefinitionName, $imageTemplateName) {
	$imageVersions = (az sig image-version list --resource-group $resourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
	foreach ($imageVersion in $imageVersions) {
		if ($imageVersion.tags.imageTemplate -eq $imageTemplateName) {
			return $imageVersion
		}
	}
}

function Get-MachineExtensionScript ($scriptFileName) {
	$machineExtensionScript = Get-Content "$templateRootDirectory\$scriptFileName" -Raw
	$memoryStream = New-Object System.IO.MemoryStream
	$compressionStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
	$streamWriter = New-Object System.IO.StreamWriter($compressionStream)
	$streamWriter.Write($machineExtensionScript)
	$streamWriter.Close();
	return [System.Convert]::ToBase64String($memoryStream.ToArray())	
}