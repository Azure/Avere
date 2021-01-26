function New-TraceMessage ($moduleName, $moduleEnd, $regionName) {
    $traceMessage = Get-Date -Format "hh:mm:ss"
    if ($regionName) {
        $traceMessage += " ($regionName)"
    }
    $traceMessage += " $moduleName"
    if (!$moduleName.Contains("Build") -and !$moduleName.Contains("Job")) {
        $traceMessage += " Deployment"
    }
    if ($moduleEnd) {
        $traceMessage += " End"
    } else {
        $traceMessage += " Start"
    }
    Write-Host $traceMessage
}

function Set-ResourceGroup ($resourceGroupNamePrefix, $resourceGroupNameSuffix, $regionName) {
    $resourceGroupName = $resourceGroupNamePrefix + $resourceGroupNameSuffix
    az group create --name $resourceGroupName --location $regionName --output none
    return $resourceGroupName
}

function Set-RoleAssignment ($roleId, $principalId, $principalType, $scopeId, $scopeResourceGroup, $assignmentPropagationWait) {
    $roleAssigned = $false
    do {
        try {
            if ($scopeResourceGroup) {
                az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --output none --resource-group $scopeId
            } else {
                az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --output none --scope $scopeId
            }
            $roleAssigned = $true
        } catch {
            Write-Warning -Message $Error[0]
        }
    } while (!$roleAssigned)
    if ($assignmentPropagationWait) {
        Start-Sleep -Seconds 180
    }
}

function Set-ImageBuilderRoles ($computeNetwork, $managedIdentity, $imageGallery) {
    $principalType = "ServicePrincipal"

    $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
    Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $imageGallery.resourceGroupName $true $false

    $roleId = "9980e02c-c2be-4d73-94e8-173b1dc7cf3c" # Virtual Machine Contributor
    Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $computeNetwork.resourceGroupName $true $false
}

function Get-ModuleName ($moduleDirectory) {
    return ($moduleDirectory -creplace '[A-Z]', ' $0').Trim()
}

function Get-BaseFramework ($rootDirectory, $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $networkGatewayDeploy) {
    $moduleDirectory = "BaseFramework"
    $moduleGroupName = Get-ModuleName $moduleDirectory
    New-TraceMessage $moduleGroupName $false

    # 00 - Virtual Network
    $moduleName = "00 - Virtual Network"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Network"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/00-VirtualNetwork.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/00-VirtualNetwork.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageNetwork.value.regionName = $storageRegionName
    $templateConfig.parameters.computeNetwork.value.regionName = $computeRegionName
    $templateConfig | ConvertTo-Json -Depth 9 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageNetwork = $groupDeployment.properties.outputs.storageNetwork.value
    $computeNetwork = $groupDeployment.properties.outputs.computeNetwork.value
    New-TraceMessage $moduleName $true $computeRegionName

    # 01 - Managed Identity
    $moduleName = "01 - Managed Identity"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/01-ManagedIdentity.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/01-ManagedIdentity.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $managedIdentity = $groupDeployment.properties.outputs.managedIdentity.value
    New-TraceMessage $moduleName $true $computeRegionName

    # 02 - Key Vault
    $moduleName = "02 - Key Vault"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/02-KeyVault.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/02-KeyVault.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $keyVault = $groupDeployment.properties.outputs.keyVault.value
    New-TraceMessage $moduleName $true $computeRegionName

    # 03 - Network Gateway
    if ($networkGatewayDeploy) {
        $moduleName = "03 - Network Gateway"
        New-TraceMessage $moduleName $false $computeRegionName
        $resourceGroupNameSuffix = ".Network"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/03-NetworkGateway.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/03-NetworkGateway.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.storageNetwork.value = $storageNetwork
        $templateConfig.parameters.computeNetwork.value = $computeNetwork
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $managedIdentity = $groupDeployment.properties.outputs.managedIdentity.value
        New-TraceMessage $moduleName $true $computeRegionName
    }

    # 04 - Pipeline Insight
    $moduleName = "04 - Pipeline Insight"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/04-PipelineInsight.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/04-PipelineInsight.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
    $cognitiveAccount = $groupDeployment.properties.outputs.cognitiveAccount.value
    New-TraceMessage $moduleName $true $computeRegionName

    # 05 - Image Gallery
    $moduleName = "05 - Image Gallery"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Gallery"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/05-ImageGallery.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/05-ImageGallery.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $imageGallery = $groupDeployment.properties.outputs.imageGallery.value

    Set-ImageBuilderRoles $computeNetwork $managedIdentity $imageGallery
    New-TraceMessage $moduleName $true $computeRegionName

    # 06 - Container Registry
    $moduleName = "06 - Container Registry"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Registry"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/06-ContainerRegistry.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/06-ContainerRegistry.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $containerRegistry = $groupDeployment.properties.outputs.containerRegistry.value
    New-TraceMessage $moduleName $true $computeRegionName

    $baseFramework = New-Object PSObject
    $baseFramework | Add-Member -MemberType NoteProperty -Name "storageNetwork" -Value $storageNetwork
    $baseFramework | Add-Member -MemberType NoteProperty -Name "computeNetwork" -Value $computeNetwork
    $baseFramework | Add-Member -MemberType NoteProperty -Name "managedIdentity" -Value $managedIdentity
    $baseFramework | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
    $baseFramework | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
    $baseFramework | Add-Member -MemberType NoteProperty -Name "cognitiveAccount" -Value $cognitiveAccount
    $baseFramework | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
    $baseFramework | Add-Member -MemberType NoteProperty -Name "containerRegistry" -Value $containerRegistry

    New-TraceMessage $moduleGroupName $true
    return $baseFramework
}

function Get-StorageCache ($baseFramework, $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy) {
    $storageNetwork = $baseFramework.storageNetwork
    $computeNetwork = $baseFramework.computeNetwork
    $managedIdentity = $baseFramework.managedIdentity

    $moduleDirectory = "StorageCache"
    $moduleGroupName = Get-ModuleName $moduleDirectory
    New-TraceMessage $moduleGroupName $false

    # 07 - Storage
    $moduleName = "07 - Storage"
    New-TraceMessage $moduleName $false $storageRegionName
    $resourceGroupNameSuffix = ".Storage"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/07-Storage.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/07-Storage.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.computeRegionName.value = $computeRegionName
    $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageAccount = $groupDeployment.properties.outputs.storageAccount.value
    $storageMounts = $groupDeployment.properties.outputs.storageMounts.value
    $storageTargets = $groupDeployment.properties.outputs.storageTargets.value
    New-TraceMessage $moduleName $true $storageRegionName

    # 07 - Storage [NetApp]
    if ($storageNetAppDeploy) {
        $moduleName = "07 - Storage [NetApp]"
        New-TraceMessage $moduleName $false $storageRegionName
        $resourceGroupNameSuffix = ".Storage"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/07-Storage.NetApp.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/07-Storage.NetApp.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
        $storageTargets += $groupDeployment.properties.outputs.storageTargets.value
        New-TraceMessage $moduleName $true $storageRegionName
    }

    Set-StorageRoles $storageAccount.name $managedIdentity $storageRegionName
    Set-StorageFiles $rootDirectory $storageAccount.name $storageMounts $cacheMount

    # 08 - HPC Cache
    if ($storageCacheDeploy) {
        $moduleName = "08 - HPC Cache"
        New-TraceMessage $moduleName $false $computeRegionName
        $resourceGroupNameSuffix = ".Cache"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/08-HPCCache.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/08-HPCCache.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.storageTargets.value = $storageTargets
        $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $cacheMountAddresses = $groupDeployment.properties.outputs.mountAddresses.value
        $cacheMountOptions = $groupDeployment.properties.outputs.mountOptions.value

        $dnsRecordName = $groupDeployment.properties.outputs.virtualNetwork.value.subnetName.ToLower()
        az network private-dns record-set a delete --resource-group $computeNetwork.resourceGroupName --zone-name $computeNetwork.domainName --name $dnsRecordName --yes
        foreach ($cacheMountAddress in $cacheMountAddresses) {
            $dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetwork.resourceGroupName --zone-name $computeNetwork.domainName --record-set-name $dnsRecordName --ipv4-address $cacheMountAddress) | ConvertFrom-Json
        }

        $cacheMount = New-Object PSObject
        $cacheMount | Add-Member -MemberType NoteProperty -Name "type" -Value "nfs"
        $cacheMount | Add-Member -MemberType NoteProperty -Name "endpoint" -Value ($dnsRecord.fqdn + ":/")
        $cacheMount | Add-Member -MemberType NoteProperty -Name "path" -Value "/mnt/cache"
        $cacheMount | Add-Member -MemberType NoteProperty -Name "options" -Value $cacheMountOptions
        New-TraceMessage $moduleName $true $computeRegionName
    }

    # 09 - Event Grid
    $moduleName = "09 - Event Grid"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/09-EventGrid.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/09-EventGrid.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.storageAccount.value.queueName = $storageAccount.queueName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 3 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true $computeRegionName

    $storageCache = New-Object PSObject
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageAccount" -Value $storageAccount
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
    $storageCache | Add-Member -MemberType NoteProperty -Name "cacheMount" -Value $cacheMount

    New-TraceMessage $moduleGroupName $true
    return $storageCache
}

function Set-StorageRoles ($storageAccountName, $managedIdentity, $storageRegionName) {
    $moduleName = "Storage Roles"
    New-TraceMessage $moduleName $false $storageRegionName

    $userId = az ad signed-in-user show --query "objectId"
    $storageId = az storage account show --name $storageAccountName --query "id"

    $principalType = "User"
    $roleId = "974c5e8b-45b9-4653-ba55-5f855dd0fb88" # Storage Queue Data Contributor
    Set-RoleAssignment $roleId $userId $principalType $storageId $false $false

    $roleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Object Data Contributor
    Set-RoleAssignment $roleId $userId $principalType $storageId $false $false

    $principalType = "ServicePrincipal"
    $roleId = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" # Storage Object Data Reader
    Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $storageId $false $false

    $roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
    Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $storageId $false $true

    New-TraceMessage $moduleName $true $storageRegionName
}

function Set-StorageFiles ($rootDirectory, $storageAccountName, $storageMounts, $cacheMount) {
    $storageContainerName = "script"
    $mountFilePatternLinux = "*.mount"
    $mountFilePatternWindows = "*.bat"
    $scriptFilePatternLinux = "*-*.sh"
    $scriptFilePatternWindows = "*-*.ps1"

    $moduleName = "Storage Cache Mounts"
    $moduleDirectory = "StorageCache"
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    New-TraceMessage $moduleName $false
    Set-MountUnitFiles $sourceDirectory $storageMounts $cacheMount
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $mountFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $mountFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true

    $moduleName = "Scripts Upload [Render Manager]"
    $moduleDirectory = "RenderManager"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true

    $moduleName = "Scripts Upload [Render Farm]"
    $moduleDirectory = "RenderFarm"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true

    $moduleName = "Scripts Upload [Artist Workstation]"
    $moduleDirectory = "ArtistWorkstation"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true
}

function Get-MountUnitFileName ($mount) {
    if ($mount.junctions) {
        $path = $mount.junctions[0].namespacePath
    } else {
        $path = $mount.path
    }
    return $path.Substring(1).Replace('/', '-') + ".mount"
}

function Set-MountUnitFile ($outputDirectory, $mount) {
    $fileName = Get-MountUnitFileName $mount
    $filePath = "$outputDirectory/$fileName"
    Out-File -FilePath $filePath -InputObject "[Unit]"
    Out-File -FilePath $filePath -InputObject "After=network-online.target" -Append
    Out-File -FilePath $filePath -InputObject "" -Append
    Out-File -FilePath $filePath -InputObject "[Mount]" -Append
    Out-File -FilePath $filePath -InputObject ("Type=" + $mount.type) -Append
    Out-File -FilePath $filePath -InputObject ("What=" + $mount.endpoint) -Append
    Out-File -FilePath $filePath -InputObject ("Where=" + $mount.path) -Append
    Out-File -FilePath $filePath -InputObject ("Options=" + $mount.options) -Append
    Out-File -FilePath $filePath -InputObject "" -Append
    Out-File -FilePath $filePath -InputObject "[Install]" -Append
    Out-File -FilePath $filePath -InputObject "WantedBy=multi-user.target" -Append
}

function Set-MountUnitFiles ($outputDirectory, $storageMounts, $cacheMount) {
    foreach ($storageMount in $storageMounts) {
        Set-MountUnitFile $sourceDirectory $storageMount
    }
    if ($cacheMount) {
        Set-MountUnitFile $sourceDirectory $cacheMount
    }
}

function Get-ScriptUri ($storageAccounts, $scriptDirectory, $scriptFile) {
    $storageAccount = $storageAccounts[0]
    return "https://" + $storageAccount.name + ".blob.core.windows.net/script/$scriptDirectory/$scriptFile"
}

function Get-ScriptChecksum ($rootDirectory, $moduleDirectory, $scriptDirectory, $scriptFile) {
    $filePath = "$rootDirectory/$moduleDirectory"
    if ($scriptDirectory -ne "") {
        $filePath = "$filePath/$scriptDirectory"
    }
    $filePath = "$filePath/$scriptFile"
    $fileHash = Get-FileHash -Path $filePath -Algorithm "SHA256"
    return $fileHash.hash.ToLower()
}

function Get-ImageVersion ($imageGallery, $imageTemplate) {
    $imageVersions = (az sig image-version list --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageTemplate.imageDefinitionName) | ConvertFrom-Json
    foreach ($imageVersion in $imageVersions) {
        if ($imageVersion.tags.imageTemplateName -eq $imageTemplate.name) {
            return $imageVersion
        }
    }
}

function Set-ImageTemplates ($resourceGroupName, $imageTemplates, $osType) {
    $deployEnabled = $false
    foreach ($imageTemplate in $imageTemplates) {
        if ($imageTemplate.imageOperatingSystemType -eq $osType) {
            $imageTemplate.deploy = $true
            $templateName = $imageTemplate.name
            $templates = (az image builder list --resource-group $resourceGroupName --query "[?contains(name, '$templateName')]") | ConvertFrom-Json
            if ($templates.length -eq 0) {
                $deployEnabled = $true
            }
        }
    }
    return $deployEnabled
}

function Build-ImageTemplates ($moduleName, $computeRegionName, $imageGallery, $imageTemplates) {
    New-TraceMessage $moduleName $false $computeRegionName
    foreach ($imageTemplate in $imageTemplates) {
        if ($imageTemplate.deploy) {
            $imageVersion = Get-ImageVersion $imageGallery $imageTemplate
            if (!$imageVersion) {
                New-TraceMessage "$moduleName [$($imageTemplate.name)]" $false $computeRegionName
                az image builder run --resource-group $resourceGroupName --name $imageTemplate.name --output none
                New-TraceMessage "$moduleName [$($imageTemplate.name)]" $true $computeRegionName
            }
        }
    }
    New-TraceMessage $moduleName $true $computeRegionName
}

function Get-ObjectProperties ($object, $windows) {
    $objectProperties = ""
    foreach ($property in $object.PSObject.Properties) {
        if ($property.Value -is [string] -and $property.Value -ne "") {
            if ($objectProperties -ne "") {
                $objectProperties += " "
            }
            if ($windows) {
                $objectProperties += "-" + $property.Name + " '" + $property.Value + "'"
            } else {
                $objectProperties += $property.Name + "='" + $property.Value + "'"
            }
        }
    }
    return $objectProperties
}
