function Get-StorageCache ($rootDirectory, $baseFramework, $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppDeploy, $storageCacheDeploy) {
    $storageNetwork = $baseFramework.storageNetwork
    $computeNetwork = $baseFramework.computeNetwork
    $networkDomain = $baseFramework.networkDomain
    $managedIdentity = $baseFramework.managedIdentity

    $moduleDirectory = "StorageCache"

    # (09.1) Storage
    $moduleName = "(09.1) Storage"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Storage"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/09-Storage.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/09-Storage.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.computeRegionName.value = $computeRegionName
    $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageAccount = $groupDeployment.properties.outputs.storageAccount.value
    $storageMounts = $groupDeployment.properties.outputs.storageMounts.value
    $storageTargets = $groupDeployment.properties.outputs.storageTargets.value

    Set-RoleAssignments "Storage" $storageAccount.name $computeNetwork $managedIdentity $keyVault $imageGallery
    New-TraceMessage $moduleName $true

    # (09.2) Storage [NetApp]
    if ($storageNetAppDeploy) {
        $moduleName = "(09.2) Storage [NetApp]"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Storage"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/09-Storage.NetApp.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/09-Storage.NetApp.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
        $storageTargets += $groupDeployment.properties.outputs.storageTargets.value
        New-TraceMessage $moduleName $true
    }

    Set-StorageFiles "(09.3)" $rootDirectory $storageAccount.name $storageMounts $cacheMount

    # (10) HPC Cache
    if ($storageCacheDeploy) {
        $moduleName = "(10) HPC Cache"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Cache"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/10-HPCCache.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/10-HPCCache.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.storageTargets.value = $storageTargets
        $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $cacheMountAddresses = $groupDeployment.properties.outputs.mountAddresses.value
        $cacheMountOptions = $groupDeployment.properties.outputs.mountOptions.value

        $dnsRecordName = $groupDeployment.properties.outputs.virtualNetwork.value.subnetName.ToLower()
        az network private-dns record-set a delete --resource-group $computeNetwork.resourceGroupName --zone-name $networkDomain.zoneName --name $dnsRecordName --yes
        foreach ($cacheMountAddress in $cacheMountAddresses) {
            $dnsRecord = (az network private-dns record-set a add-record --resource-group $computeNetwork.resourceGroupName --zone-name $networkDomain.zoneName --record-set-name $dnsRecordName --ipv4-address $cacheMountAddress) | ConvertFrom-Json
        }

        $cacheMount = New-Object PSObject
        $cacheMount | Add-Member -MemberType NoteProperty -Name "type" -Value "nfs"
        $cacheMount | Add-Member -MemberType NoteProperty -Name "host" -Value ($dnsRecord.fqdn + ":/")
        $cacheMount | Add-Member -MemberType NoteProperty -Name "path" -Value "/mnt/cache"
        $cacheMount | Add-Member -MemberType NoteProperty -Name "options" -Value $cacheMountOptions
        New-TraceMessage $moduleName $true
    }

    # (11) Event Grid
    $moduleName = "(11) Event Grid"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = ""
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/11-EventGrid.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/11-EventGrid.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.storageAccount.value.name = $storageAccount.name
    $templateConfig.parameters.storageAccount.value.resourceGroupName = $storageAccount.resourceGroupName
    $templateConfig.parameters.storageAccount.value.queueName = $storageAccount.queueName
    $templateConfig.parameters.virtualNetwork.value.name = $computeNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    New-TraceMessage $moduleName $true

    $storageCache = New-Object PSObject
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageAccount" -Value $storageAccount
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
    $storageCache | Add-Member -MemberType NoteProperty -Name "cacheMount" -Value $cacheMount
    return $storageCache
}

function Set-StorageFiles ($modulePrefix, $rootDirectory, $storageAccountName, $storageMounts, $cacheMount) {
    $storageContainerName = "script"
    $mountFilePatternLinux = "*.mount"
    $mountFilePatternWindows = "*.bat"
    $scriptFilePatternLinux = "*-*.sh"
    $scriptFilePatternWindows = "*-*.ps1"

    $moduleName = "$modulePrefix Storage Cache Mounts Upload"
    $moduleDirectory = "StorageCache"
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    New-TraceMessage $moduleName $false
    Set-MountUnitFiles $sourceDirectory $storageMounts $cacheMount
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $mountFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $mountFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true

    $moduleName = "$modulePrefix Scripts Upload [Render Manager]"
    $moduleDirectory = "RenderManager"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true

    $moduleName = "$modulePrefix Scripts Upload [Render Farm]"
    $moduleDirectory = "RenderFarm"
    New-TraceMessage $moduleName $false
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = "$storageContainerName/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none
    New-TraceMessage $moduleName $true

    $moduleName = "$modulePrefix Scripts Upload [Artist Workstation]"
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
    Out-File -FilePath $filePath -InputObject ("What=" + $mount.host) -Append
    Out-File -FilePath $filePath -InputObject ("Where=" + $mount.path) -Append
    Out-File -FilePath $filePath -InputObject ("Options=" + $mount.options) -Append
    Out-File -FilePath $filePath -InputObject "" -Append
    Out-File -FilePath $filePath -InputObject "[Install]" -Append
    Out-File -FilePath $filePath -InputObject "WantedBy=multi-user.target" -Append
}

function Set-MountUnitFiles ($outputDirectory, $storageMounts, $cacheMount) {
    foreach ($storageMount in $storageMounts) {
        Set-MountUnitFile $outputDirectory $storageMount
    }
    if ($cacheMount) {
        Set-MountUnitFile $outputDirectory $cacheMount
    }
}
