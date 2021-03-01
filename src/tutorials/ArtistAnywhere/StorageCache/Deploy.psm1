function Get-StorageCache ($rootDirectory, $baseFramework, $resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageServiceDeploy, $storageCacheDeploy) {
    $storageNetwork = $baseFramework.storageNetwork
    $computeNetwork = $baseFramework.computeNetwork
    $networkDomain = $baseFramework.networkDomain
    $managedIdentity = $baseFramework.managedIdentity

    $moduleDirectory = "StorageCache"

    $storageMounts = @()
    $storageTargets = @()

    # (06.1) Storage
    $moduleName = "(06.1) Storage"
    New-TraceMessage $moduleName $false
    $resourceGroupNameSuffix = "-Storage"
    $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

    $templateFile = "$rootDirectory/$moduleDirectory/06-Storage.json"
    $templateParameters = "$rootDirectory/$moduleDirectory/06-Storage.Parameters.json"

    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    $templateConfig.parameters.computeRegionName.value = $computeRegionName
    $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
    $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
    $storageAccount = $groupDeployment.properties.outputs.storageAccount.value
    $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
    $storageTargets += $groupDeployment.properties.outputs.storageTargets.value

    Set-RoleAssignments "Storage" $storageAccount.name $computeNetwork $managedIdentity $keyVault $imageGallery
    New-TraceMessage $moduleName $true

    # (06.2) Storage [NetApp]
    if ($storageServiceDeploy.netAppFiles) {
        $moduleName = "(06.2) Storage [NetApp]"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Storage"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/06-Storage.NetApp.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/06-Storage.NetApp.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
        $storageTargets += $groupDeployment.properties.outputs.storageTargets.value
        New-TraceMessage $moduleName $true
    }

    # (06.3) Storage [Qumulo]
    if ($storageServiceDeploy.qumulo) {
        $moduleName = "(06.3) Storage [Qumulo]"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Storage"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/06-Storage.Qumulo.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/06-Storage.Qumulo.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
        $storageTargets += $groupDeployment.properties.outputs.storageTargets.value
        New-TraceMessage $moduleName $true
    }

    # (06.4) Storage [Hammerspace]
    if ($storageServiceDeploy.hammerspace) {
        $moduleName = "(06.4) Storage [Hammerspace]"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Storage"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/06-Storage.Hammerspace.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/06-Storage.Hammerspace.Parameters.json"

        $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
        $templateConfig.parameters.virtualNetwork.value.name = $storageNetwork.name
        $templateConfig.parameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        $templateConfig | ConvertTo-Json -Depth 10 | Out-File $templateParameters

        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json
        $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
        $storageTargets += $groupDeployment.properties.outputs.storageTargets.value
        New-TraceMessage $moduleName $true
    }

    Set-StorageScripts "(06.5)" $rootDirectory $storageAccount $storageMounts $cacheMount

    # (07) HPC Cache
    if ($storageCacheDeploy) {
        $moduleName = "(07) HPC Cache"
        New-TraceMessage $moduleName $false
        $resourceGroupNameSuffix = "-Cache"
        $resourceGroupName = Set-ResourceGroup $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName

        $templateFile = "$rootDirectory/$moduleDirectory/07-HPCCache.json"
        $templateParameters = "$rootDirectory/$moduleDirectory/07-HPCCache.Parameters.json"

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

    $storageCache = New-Object PSObject
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageAccount" -Value $storageAccount
    $storageCache | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
    $storageCache | Add-Member -MemberType NoteProperty -Name "cacheMount" -Value $cacheMount
    return $storageCache
}

function Set-StorageScripts ($modulePrefix, $rootDirectory, $storageAccount, $storageMounts, $cacheMount) {
    $mountFilePattern = "*.mount"
    $scriptFilePatternLinux = "*-*.sh"
    $scriptFilePatternWindows = "*-*.ps1"

    $moduleName = "$modulePrefix Storage Scripts Upload"
    New-TraceMessage $moduleName $false

    $moduleDirectory = "StorageCache"
    $sourceDirectory = "$rootDirectory/$moduleDirectory/Linux"
    Set-MountUnitFiles $sourceDirectory $storageMounts $cacheMount
    $destinationDirectory = $storageAccount.containerName + "/$moduleDirectory/Linux"
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $mountFilePattern --auth-mode login --no-progress --output none
    $sourceDirectory = "$rootDirectory/$moduleDirectory/Windows"
    Set-MountUnitFiles $sourceDirectory $storageMounts $cacheMount
    $destinationDirectory = $storageAccount.containerName + "/$moduleDirectory/Windows"
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $mountFilePattern --auth-mode login --no-progress --output none

    $moduleDirectory = "RenderManager"
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = $storageAccount.containerName + "/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none

    $moduleDirectory = "RenderFarm"
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = $storageAccount.containerName + "/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none

    $moduleDirectory = "ArtistWorkstation"
    $sourceDirectory = "$rootDirectory/$moduleDirectory"
    $destinationDirectory = $storageAccount.containerName + "/$moduleDirectory"
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternLinux --auth-mode login --no-progress --output none
    az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern $scriptFilePatternWindows --auth-mode login --no-progress --output none

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
