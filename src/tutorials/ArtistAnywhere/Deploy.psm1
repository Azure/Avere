function New-TraceMessage ($moduleName, $moduleEnd, $regionName) {
    $message = Get-Date -Format "hh:mm:ss"
    if ($regionName) {
        $message += " ($regionName)"
    }
    $message += " $moduleName"
    if (!$moduleName.Contains("Job")) {
        $message += " Deployment"
    }
    if ($moduleEnd) {
        $message += " End"
    } else {
        $message += " Start"
    }
    Write-Host $message
}

function New-ResourceGroup ($resourceGroupNamePrefix, $resourceGroupNameSuffix, $regionName) {
    $resourceGroupName = $resourceGroupNamePrefix
    if ($resourceGroupNameSuffix -ne "") {
        $resourceGroupName += $resourceGroupNameSuffix
    }
    $resourceGroupExists = az group exists --name $resourceGroupName
    if ($resourceGroupExists -eq $false) {
        $resourceGroup = az group create --name $resourceGroupName --location $regionName
    }
    return $resourceGroupName
}

function Get-VirtualNetwork ($virtualNetworks, $regionName) {
    foreach ($virtualNetwork in $virtualNetworks) {
        if ($virtualNetwork.regionName -eq $regionName) {
            return $virtualNetwork
        }
    }
    return $virtualNetworks[0]
}

function Get-SharedFramework ($resourceGroupNamePrefix, $sharedRegionName, $computeRegionName, $storageRegionName) {
    $moduleDirectory = "SharedFramework"
    $moduleGroupName = "Shared Framework"
    New-TraceMessage $moduleGroupName $false

    # 00 - Virtual Network
    $moduleName = "00 - Virtual Network"
    New-TraceMessage $moduleName $false $sharedRegionName
    $resourceGroupNameSuffix = ".Network"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $sharedRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/00-VirtualNetwork.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/00-VirtualNetwork.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageNetwork.value.regionName = $storageRegionName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageNetwork = $groupDeployment.properties.outputs.storageNetwork.value
    $computeNetworks = $groupDeployment.properties.outputs.computeNetworks.value
    $sharedNetwork = Get-VirtualNetwork $computeNetworks $sharedRegionName
    $computeNetwork = Get-VirtualNetwork $computeNetworks $computeRegionName
    New-TraceMessage $moduleName $true $sharedRegionName

    # 01 - Managed Identity
    $moduleName = "01 - Managed Identity"
    New-TraceMessage $moduleName $false $sharedRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $sharedRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/01-ManagedIdentity.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/01-ManagedIdentity.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $managedIdentity = $groupDeployment.properties.outputs.managedIdentity.value
    New-TraceMessage $moduleName $true $sharedRegionName

    # 02 - Key Vault
    $moduleName = "02 - Key Vault"
    New-TraceMessage $moduleName $false $sharedRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $sharedRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/02-KeyVault.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/02-KeyVault.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.virtualNetwork.value.name = $sharedNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $sharedNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 3 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $keyVault = $groupDeployment.properties.outputs.keyVault.value
    New-TraceMessage $moduleName $true $sharedRegionName

    # 03 - Monitor Insight
    $moduleName = "03 - Monitor Insight"
    New-TraceMessage $moduleName $false $sharedRegionName
    $resourceGroupNameSuffix = ""
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $sharedRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/03-MonitorInsight.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/03-MonitorInsight.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
    New-TraceMessage $moduleName $true $sharedRegionName

    # 04 - Image Gallery
    $moduleName = "04 - Image Gallery"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Gallery"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/04-ImageGallery.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/04-ImageGallery.Parameters.json"

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $imageGallery = $groupDeployment.properties.outputs.imageGallery.value

    $principalType = "ServicePrincipal"

    # Azure Image Builder (AIB) Role Assignment
    $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
    $roleAssignment = az role assignment create --role $roleId --resource-group $imageGallery.resourceGroupName --assignee-object-id $managedIdentity.principalId --assignee-principal-type $principalType

    # Azure Image Builder (AIB) Role Assignment
    $roleId = "9980e02c-c2be-4d73-94e8-173b1dc7cf3c" # Virtual Machine Contributor
    $roleAssignment = az role assignment create --role $roleId --resource-group $computeNetwork.resourceGroupName --assignee-object-id $managedIdentity.principalId --assignee-principal-type $principalType

    New-TraceMessage $moduleName $true $computeRegionName

    # 05 - Container Registry
    $moduleName = "05 - Container Registry"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupNameSuffix = ".Registry"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/05-ContainerRegistry.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/05-ContainerRegistry.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.managedIdentity.value.name = $managedIdentity.name
    $templateConfig.parameters.managedIdentity.value.resourceGroupName = $managedIdentity.resourceGroupName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 3 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $containerRegistry = $groupDeployment.properties.outputs.containerRegistry.value
    New-TraceMessage $moduleName $true $computeRegionName

    $sharedFramework = New-Object PSObject
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "storageNetwork" -Value $storageNetwork
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "computeNetworks" -Value $computeNetworks
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "managedIdentity" -Value $managedIdentity
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
    $sharedFramework | Add-Member -MemberType NoteProperty -Name "containerRegistry" -Value $containerRegistry

    New-TraceMessage $moduleGroupName $true
    return $sharedFramework
}

function Get-StorageCache ($sharedFramework, $resourceGroupNamePrefix, $computeRegionName, $cacheRegionName, $storageRegionName, $storageNetAppDeploy) {
    $moduleDirectory = "StorageCache"

    $storageNetwork = $sharedFramework.storageNetwork
    $computeNetwork = Get-VirtualNetwork $sharedFramework.computeNetworks $computeRegionName
    $managedIdentity = $sharedFramework.managedIdentity

    $moduleGroupName = "Storage Cache"
    New-TraceMessage $moduleGroupName $false

    # 06 - Storage
    $moduleName = "06 - Storage"
    New-TraceMessage $moduleName $false $storageRegionName
    $resourceGroupNameSuffix = ".Storage"
    $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/06-Storage.json"
    $templateParameters = "$templateDirectory/$moduleDirectory/06-Storage.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 7 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageAccounts = $groupDeployment.properties.outputs.storageAccounts.value
    $storageMounts = $groupDeployment.properties.outputs.storageMounts.value
    $storageTargets = $groupDeployment.properties.outputs.storageTargets.value
    New-TraceMessage $moduleName $true $storageRegionName

    # 06 - Storage [NetApp]
    if ($storageNetAppDeploy) {
        $moduleName = "06 - Storage [NetApp]"
        New-TraceMessage $moduleName $false $storageRegionName
        $resourceGroupNameSuffix = ".Storage"
        $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

        $templateFile = "$templateDirectory/$moduleDirectory/06-Storage.NetApp.json"
        $templateParameters = "$templateDirectory/$moduleDirectory/06-Storage.NetApp.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $storageAccounts += $groupDeployment.properties.outputs.storageAccounts.value
        $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
        $netAppTargets = Get-UniqueTargets $groupDeployment.properties.outputs.storageTargets.value "NFSv3"

        $netAppAccounts = (az netappfiles account list --resource-group $resourceGroupName) | ConvertFrom-Json
        foreach ($netAppAccount in $netAppAccounts) {
            $netAppPools = (az netappfiles pool list --resource-group $resourceGroupName --account-name $netAppAccount.name) | ConvertFrom-Json
            foreach ($netAppPool in $netAppPools) {
                $netAppPoolName = $netAppPool.name.Substring($netAppAccount.name.length + 1)
                $netAppVolumes = (az netappfiles volume list --resource-group $resourceGroupName --account-name $netAppAccount.name --pool-name $netAppPoolName) | ConvertFrom-Json -AsHashTable
                foreach ($netAppVolume in $netAppVolumes) {
                    $sourceAddress = $netAppVolume.mountTargets[0].ipAddress
                    foreach ($netAppTarget in $netAppTargets) {
                        if ($netAppTarget.source -eq $sourceAddress) {
                            $nfsExport = "/" + $netAppVolume.name.ToLower()
                            $namespacePath = "/storage" + $nfsExport
                            $junction = New-Object PSObject
                            $junction | Add-Member -MemberType NoteProperty -Name "namespacePath" -Value $namespacePath
                            $junction | Add-Member -MemberType NoteProperty -Name "nfsExport" -Value $nfsExport
                            $junction | Add-Member -MemberType NoteProperty -Name "targetPath" -Value "/"
                            $netAppTarget.junctions += $junction
                        }
                    }
                }
            }
        }

        $storageTargets += $netAppTargets
        New-TraceMessage $moduleName $true $storageRegionName
    }

    # 07 - Cache
    $cacheMounts = @()
    if ($cacheRegionName -ne "") {
        $cacheNetwork = Get-VirtualNetwork $sharedFramework.computeNetworks $cacheRegionName
        $moduleName = "07 - Cache"
        New-TraceMessage $moduleName $false $cacheNetwork.regionName
        $resourceGroupNameSuffix = ".Cache"
        $resourceGroupName = New-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $cacheNetwork.regionName

        $templateFile = "$templateDirectory/$moduleDirectory/07-Cache.json"
        $templateParameters = "$templateDirectory/$moduleDirectory/07-Cache.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.storageTargets.value = $storageTargets
        $templateConfig.parameters.virtualNetwork.value.name = $cacheNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $cacheNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 6 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $cacheName = $groupDeployment.properties.outputs.cacheName.value
        $cacheMountAddresses = $groupDeployment.properties.outputs.mountAddresses.value
        $cacheMountOptions = $groupDeployment.properties.outputs.mountOptions.value

        $dnsRecordName = $groupDeployment.properties.outputs.virtualNetwork.value.subnetName.ToLower()
        az network private-dns record-set a delete --resource-group $computeNetwork.resourceGroupName --zone-name $computeNetwork.domainName --name $dnsRecordName --yes
        foreach ($cacheMountAddress in $cacheMountAddresses) {
            $dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetwork.resourceGroupName --zone-name $computeNetwork.domainName --record-set-name $dnsRecordName --ipv4-address $cacheMountAddress) | ConvertFrom-Json
        }

        $storageTargets = (az hpc-cache storage-target list --resource-group $resourceGroupName --cache-name $cacheName) | ConvertFrom-Json
        if ($storageTargets.length -gt 0) {
            $cacheMountSource = $dnsRecord.fqdn + ":" + $storageTargets[0].junctions[0].namespacePath
            $cacheMount = New-Object PSObject
            $cacheMount | Add-Member -MemberType NoteProperty -Name "source" -Value $cacheMountSource
            $cacheMount | Add-Member -MemberType NoteProperty -Name "options" -Value $cacheMountOptions
            $cacheMount | Add-Member -MemberType NoteProperty -Name "path" -Value "cache"
            $cacheMounts += $cacheMount
        }
        New-TraceMessage $moduleName $true $cacheNetwork.regionName
    }

    $storageAccount = $storageAccounts[0]
    Set-StorageAccess $storageAccount.name $managedIdentity
    Set-StorageScripts $storageAccount.name $storageMounts $cacheMounts

    $storageCache = New-Object PSObject
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageAccounts" -Value $storageAccounts
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
    $storageCache | Add-Member -MemberType NoteProperty -Name "cacheMounts" -Value $cacheMounts

    New-TraceMessage $moduleGroupName $true
    return $storageCache
}

function Set-StorageAccess ($storageAccountName, $managedIdentity) {
    $userId = az ad signed-in-user show --query "objectId"
    $storageId = az storage account show --name $storageAccountName --query "id"

    $principalType = "User"
    $roleId = "974c5e8b-45b9-4653-ba55-5f855dd0fb88" # Storage Queue Data Contributor
    $roleAssignment = az role assignment create --role $roleId --scope $storageId --assignee-object-id $userId --assignee-principal-type $principalType

    $roleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Object Data Contributor
    $roleAssignment = az role assignment create --role $roleId --scope $storageId --assignee-object-id $userId --assignee-principal-type $principalType

    $principalType = "ServicePrincipal"
    $roleId = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" # Storage Object Data Reader
    $roleAssignment = az role assignment create --role $roleId --scope $storageId --assignee-object-id $managedIdentity.principalId --assignee-principal-type $principalType

    $roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
    $roleAssignment = az role assignment create --role $roleId --scope $storageId --assignee-object-id $managedIdentity.principalId --assignee-principal-type $principalType

    Start-Sleep -Seconds 180 # Ensures role assignment propagation
}

function Get-MountUnitFileName ($mount) {
    return $mount.path.Substring(1).Replace('/', '-') + ".mount"
}

function New-MountUnitFile ($sourceDirectory, $mount) {
    $fileName = Get-MountUnitFileName $mount
    $filePath = "$sourceDirectory/$fileName"
    Out-File -FilePath $filePath -InputObject "[Unit]"
    Out-File -FilePath $filePath -InputObject "" -Append
    Out-File -FilePath $filePath -InputObject "[Mount]" -Append
    $unitInput = "What=" + $mount.source
    Out-File -FilePath $filePath -InputObject $unitInput -Append
    $unitInput = "Where=" + $mount.path
    Out-File -FilePath $filePath -InputObject $unitInput -Append
    Out-File -FilePath $filePath -InputObject "Type=nfs" -Append
    $unitInput = "Options=" + $mount.options
    Out-File -FilePath $filePath -InputObject $unitInput -Append
    Out-File -FilePath $filePath -InputObject "" -Append
    Out-File -FilePath $filePath -InputObject "[Install]" -Append
    Out-File -FilePath $filePath -InputObject "WantedBy=multi-user.target" -Append
}

function Set-StorageScripts ($storageAccountName, $storageMounts, $cacheMounts) {
    $storageContainerName = "script"

    $moduleName = "Storage Cache Mounts"
    $moduleDirectory = "StorageCache"
    $sourceDirectory = "$templateDirectory/$moduleDirectory"
    New-TraceMessage $moduleName $false
    foreach ($storageMount in $storageMounts) {
        New-MountUnitFile $sourceDirectory $storageMount
    }
    foreach ($cacheMount in $cacheMounts) {
        New-MountUnitFile $sourceDirectory $cacheMount
    }
    $blobUpload = az storage blob upload-batch --account-name $storageAccountName --destination $storageContainerName --source $sourceDirectory --pattern '*.mount' --auth-mode login --no-progress
    New-TraceMessage $moduleName $true

    $moduleName = "Scripts Upload (Render Manager)"
    $moduleDirectory = "RenderManager"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$templateDirectory/$moduleDirectory"
    $blobUpload = az storage blob upload-batch --account-name $storageAccountName --destination $storageContainerName --source $sourceDirectory --pattern '*.sh' --auth-mode login --no-progress
    New-TraceMessage $moduleName $true

    $moduleName = "Scripts Upload (Render Farm)"
    $moduleDirectory = "RenderFarm"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$templateDirectory/$moduleDirectory"
    $blobUpload = az storage blob upload-batch --account-name $storageAccountName --destination $storageContainerName --source $sourceDirectory --pattern '*.sh' --auth-mode login --no-progress
    New-TraceMessage $moduleName $true

    $moduleName = "Scripts Upload (Artist Workstation)"
    $moduleDirectory = "ArtistWorkstation"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$templateDirectory/$moduleDirectory"
    $blobUpload = az storage blob upload-batch --account-name $storageAccountName --destination $storageContainerName --source $sourceDirectory --pattern '*.sh' --auth-mode login --no-progress
    $blobUpload = az storage blob upload-batch --account-name $storageAccountName --destination $storageContainerName --source $sourceDirectory --pattern '*.ps1' --auth-mode login --no-progress
    New-TraceMessage $moduleName $true
}

function Get-UniqueTargets ($storageTargets, $requiredProtocol) {
    $uniqueTargets = ""
    foreach ($storageTarget in $storageTargets) {
        $storageTargetJson = ConvertTo-Json -InputObject $storageTarget
        if (!$uniqueTargets.Contains($storageTargetJson) -and $storageTargetJson.Contains($requiredProtocol)) {
            if ($uniqueTargets -ne "") {
                $uniqueTargets += ","
            }
            $uniqueTargets += $storageTargetJson
        }
    }
    return ConvertFrom-Json -InputObject "[$uniqueTargets]"
}

function Get-ScriptUri ($storageAccounts, $scriptFile) {
    $storageAccount = $storageAccounts[0]
    return "https://" + $storageAccount.name + ".blob.core.windows.net/script/" + $scriptFile
}

function Get-ScriptChecksum ($moduleDirectory, $scriptFile) {
    $filePath = "$templateDirectory/$moduleDirectory/$scriptFile"
    $fileHash = Get-FileHash -Path $filePath -Algorithm "SHA256"
    return $fileHash.hash.ToLower()
}

function Confirm-ImageTemplates ($resourceGroupName, $imageTemplates) {
    foreach ($imageTemplate in $imageTemplates) {
        $templateName = $imageTemplate.name
        $templates = (az image builder list --resource-group $resourceGroupName --query "[?contains(name, '$templateName')]") | ConvertFrom-Json
        if ($templates.length -eq 0) {
            return $true
        }
    }
    return $false
}

function Get-ImageVersion ($imageGallery, $imageTemplate) {
    $imageVersions = (az sig image-version list --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageTemplate.imageDefinitionName) | ConvertFrom-Json
    foreach ($imageVersion in $imageVersions) {
        if ($imageVersion.tags.imageTemplateName -eq $imageTemplate.name) {
            return $imageVersion
        }
    }
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
