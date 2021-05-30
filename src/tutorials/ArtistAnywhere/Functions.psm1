function New-TraceMessage ($moduleName, $moduleEnd) {
  $traceMessage = Get-Date -Format "hh:mm:ss"
  if ($moduleEnd) {
    $traceMessage += "   END"
  } else {
    $traceMessage += " START"
  }
  Write-Host "$traceMessage $moduleName"
}

function Set-ResourceGroup ($regionName, $resourceGroupNamePrefix, $resourceGroupNameSuffix) {
  $resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix
  az group create --name $resourceGroupName --location $regionName --output none
  return $resourceGroupName
}

function Set-OverrideParameter ($templateParametersPath, $objectName, $propertyName, $propertyValue) {
  $valueReference = ($propertyName -eq "keyVault" -or $propertyName -eq "secretName") ? "reference" : "value"
  $templateParameters = Get-Content -Path $templateParametersPath -Raw | ConvertFrom-Json
  if ($propertyName -eq "") {
    $templateParameters.parameters.$objectName.$valueReference = $propertyValue
  } elseif ($propertyName.Contains(".")) {
    $propertyNames = $propertyName.Split(".")
    $templateParameters.parameters.$objectName.$valueReference.($propertyNames[0]).($propertyNames[1]) = $propertyValue
  } else {
    $templateParameters.parameters.$objectName.$valueReference.$propertyName = $propertyValue
  }
  $templateParameters | ConvertTo-Json -Depth 10 | Out-File $templateParametersPath
}

function Set-StorageScripts ($rootDirectory, $moduleDirectory, $storageAccountName, $storageContainerName) {
  $functionName = "(**) Set Storage Scripts"
  $systemType = "Linux"
  $scriptFilePattern = "[0-9]*.sh"
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" $false
  $sourceDirectory = "$rootDirectory/$moduleDirectory/$systemType"
  $destinationDirectory = "$storageContainerName/$moduleDirectory/$systemType"
  az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern "$scriptFilePattern" --auth-mode login --output none --no-progress
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" $true
  $systemType = "Windows"
  $scriptFilePattern = "[0-9]*.ps1"
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" $false
  $sourceDirectory = "$rootDirectory/$moduleDirectory/$systemType"
  $destinationDirectory = "$storageContainerName/$moduleDirectory/$systemType"
  az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern "$scriptFilePattern" --auth-mode login --output none --no-progress
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" $true
}

function Get-ImageVersion ($imageTemplate, $imageGallery) {
  $imageVersions = (az sig image-version list --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageTemplate.imageDefinitionName) | ConvertFrom-Json
  foreach ($imageVersion in $imageVersions) {
    if ($imageVersion.tags.imageTemplateName -eq $imageTemplate.name) {
      return $imageVersion
    }
  }
}

function Build-ImageTemplates ($moduleName, $computeRegionName, $imageTemplates, $imageGallery) {
  New-TraceMessage $moduleName $false
  foreach ($imageTemplate in $imageTemplates) {
    if ($imageTemplate.deploy) {
      $imageVersion = Get-ImageVersion $imageTemplate $imageGallery
      if (!$imageVersion) {
        New-TraceMessage "$moduleName [$($imageTemplate.name)]" $false
        az image builder run --resource-group $imageGallery.resourceGroupName --name $imageTemplate.name --output none
        New-TraceMessage "$moduleName [$($imageTemplate.name)]" $true
      }
    }
  }
  New-TraceMessage $moduleName $true
}
