function New-TraceMessage ($moduleName, $moduleEnd, $regionName) {
    $traceMessage = [System.DateTime]::Now.ToLongTimeString()
    if ($regionName) {
        $traceMessage += " @ " + $regionName
    }
    $traceMessage += " ($moduleName"
    if ($moduleName.Substring(0, 1) -ne "*") {
        $traceMessage += " Deployment"
    }
    if ($moduleEnd) {
        $traceMessage += " End)"
    } else {
        $traceMessage += " Start)"
    }
    Write-Host $traceMessage
}

function Get-ResourceGroupName ($resourceGroupNamePrefix, $resourceGroupNameSuffix, $regionName) {
    $resourceGroupName = $resourceGroupNamePrefix
    if ($null -ne $regionName) {
        $resourceGroupName = "$resourceGroupName.$regionName"
    }
    if ($null -ne $resourceGroupNameSuffix) {
        $resourceGroupName = "$resourceGroupName$resourceGroupNameSuffix"
    }
    return $resourceGroupName
}

function Get-SharedServices ($resourceGroupNamePrefix, $computeRegionName, $storageRegionName, $storageNetAppEnable, $vnetGatewayEnable) {
    $moduleDirectory = "StudioServices"

    # 00 - Network
    $moduleName = "00 - Network"
    $resourceGroupNameSuffix = ".Network"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/00-Network.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/00-Network.Parameters.$computeRegionName.json" -Raw | ConvertFrom-Json).parameters

    $templateParameters.virtualNetworkGateway.value.deploy = $vnetGatewayEnable

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 8).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $computeNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
    $computeNetwork | Add-Member -MemberType NoteProperty -Name "regionName" -Value $computeRegionName
    $computeNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    New-TraceMessage $moduleName $true $computeRegionName

    # 01 - Security
    $moduleName = "01 - Security"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/01-Security.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/01-Security.Parameters.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $computeNetwork.name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $userIdentity = $groupDeployment.properties.outputs.userIdentity.value
    $userIdentity | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    $logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
    $keyVault = $groupDeployment.properties.outputs.keyVault.value
    New-TraceMessage $moduleName $true $computeRegionName

    $moduleDirectory = "ImageLibrary"

    # 02 - Image Gallery
    $moduleName = "02 - Image Gallery"
    $resourceGroupNameSuffix = ".Gallery"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/02-Image.Gallery.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/02-Image.Gallery.Parameters.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.userIdentity.value.principalId -eq "") {
        $templateParameters.userIdentity.value.principalId = $userIdentity.principalId
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $imageGallery = $groupDeployment.properties.outputs.imageGallery.value
    $imageGallery | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    New-TraceMessage $moduleName $true $computeRegionName

    # 03 - Image Registry
    $moduleName = "03 - Image Registry"
    $resourceGroupNameSuffix = ".Registry"
    New-TraceMessage $moduleName $false $computeRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $computeRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $computeRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/03-Image.Registry.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/03-Image.Registry.Parameters.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.userIdentity.value.resourceId -eq "") {
        $templateParameters.userIdentity.value.resourceId = $userIdentity.resourceId
    }
    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $computeNetwork.name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $computeNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 4).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $imageRegistry = $groupDeployment.properties.outputs.imageRegistry.value
    $imageRegistry | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    New-TraceMessage $moduleName $true $computeRegionName

    $moduleDirectory = "StorageCache"

    # 04 - Storage Network
    $moduleName = "04 - Storage Network"
    $resourceGroupNameSuffix = ".Network"
    New-TraceMessage $moduleName $false $storageRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/04-Storage.Network.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Storage.Network.Parameters.json" -Raw | ConvertFrom-Json).parameters

    $templateParameters.computeNetwork.value = $computeNetwork
    $templateParameters.virtualNetworkGateway.value.deploy = $vnetGatewayEnable

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 8).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    $storageNetwork = $groupDeployment.properties.outputs.virtualNetwork.value
    $storageNetwork | Add-Member -MemberType NoteProperty -Name "resourceGroupName" -Value $resourceGroupName
    New-TraceMessage $moduleName $true $storageRegionName

    $storageMounts = @()
    $storageTargets = @()

    # 04 - Storage (NetApp)
    if ($storageNetAppEnable) {
        $storageMountsNetApp = @()
        $storageTargetsNetApp = @()
        $moduleName = "04 - Storage (NetApp)"
        $resourceGroupNameSuffix = ".Storage.NetApp"
        New-TraceMessage $moduleName $false $storageRegionName
        $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
        $resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName

        $templateFile = "$templateDirectory/$moduleDirectory/04-Storage.NetApp.json"
        $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Storage.NetApp.Parameters.json" -Raw | ConvertFrom-Json).parameters

        if ($templateParameters.virtualNetwork.value.name -eq "") {
            $templateParameters.virtualNetwork.value.name = $storageNetwork.name
        }
        if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
            $templateParameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
        }

        $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
        $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

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
                $storageNetworkName = $groupDeployment.properties.parameters.virtualNetwork.value.name
                $storageTargetsNetApp[$storageTargetIndex].name = $storageNetworkName + ".NetApp"
                $storageTargetsNetApp[$storageTargetIndex].junctions += $storageTargetTemp.junctions
            } else {
                $storageTargetsNetApp += $storageTargetTemp
            }
        }

        $storageMounts += $storageMountsNetApp
        $storageTargets += $storageTargetsNetApp
        New-TraceMessage $moduleName $true $storageRegionName
    }

    # 04 - Storage Account
    $moduleName = "04 - Storage Account"
    $resourceGroupNameSuffix = ".Storage"
    New-TraceMessage $moduleName $false $storageRegionName
    $resourceGroupName = Get-ResourceGroupName $resourceGroupNamePrefix $resourceGroupNameSuffix $storageRegionName
    $resourceGroup = az group create --resource-group $resourceGroupName --location $storageRegionName

    $templateFile = "$templateDirectory/$moduleDirectory/04-Storage.Account.json"
    $templateParameters = (Get-Content "$templateDirectory/$moduleDirectory/04-Storage.Account.Parameters.json" -Raw | ConvertFrom-Json).parameters

    if ($templateParameters.virtualNetwork.value.name -eq "") {
        $templateParameters.virtualNetwork.value.name = $storageNetwork.name
    }
    if ($templateParameters.virtualNetwork.value.resourceGroupName -eq "") {
        $templateParameters.virtualNetwork.value.resourceGroupName = $storageNetwork.resourceGroupName
    }

    $templateParameters = '"{0}"' -f ($templateParameters | ConvertTo-Json -Compress -Depth 5).Replace('"', '\"')
    $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters) | ConvertFrom-Json

    # $storageMounts += $groupDeployment.properties.outputs.storageMounts.value
    # $storageTargets += $groupDeployment.properties.outputs.storageTargets.value

    $storageAccountName = "mediastudio"
    $storageContainerName = "scripts"

    $moduleDirectory = "RenderManager"

    $fileName = "07-Manager.Images.Customize.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "07-Manager.Images.Customize.OpenCue.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "07-Manager.Images.Customize.Blender.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "08-Manager.Machines.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "08-Manager.Machines.DataAccess.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $moduleDirectory = "RenderWorker"

    $fileName = "09-Worker.Images.Customize.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "09-Worker.Images.Customize.OpenCue.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "09-Worker.Images.Customize.Blender.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "10-Worker.Machines.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $moduleDirectory = "ArtistDesktop"

    $fileName = "11-Desktop.Images.Customize.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "11-Desktop.Images.Customize.ps1"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "11-Desktop.Images.Customize.OpenCue.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "11-Desktop.Images.Customize.OpenCue.ps1"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "11-Desktop.Images.Customize.Blender.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "11-Desktop.Images.Customize.Blender.ps1"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "12-Desktop.Machines.sh"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    $fileName = "12-Desktop.Machines.ps1"
    $filePath = "$templateDirectory/$moduleDirectory/$fileName"
    New-TraceMessage $fileName $false
    az storage blob upload --account-name $storageAccountName --container-name $storageContainerName --name $fileName --file $filePath --only-show-errors
    New-TraceMessage $fileName $true

    New-TraceMessage $moduleName $true $storageRegionName

    $sharedServices = New-Object PSObject
    $sharedServices | Add-Member -MemberType NoteProperty -Name "computeNetwork" -Value $computeNetwork
    $sharedServices | Add-Member -MemberType NoteProperty -Name "userIdentity" -Value $userIdentity
    $sharedServices | Add-Member -MemberType NoteProperty -Name "logAnalytics" -Value $logAnalytics
    $sharedServices | Add-Member -MemberType NoteProperty -Name "keyVault" -Value $keyVault
    $sharedServices | Add-Member -MemberType NoteProperty -Name "imageGallery" -Value $imageGallery
    $sharedServices | Add-Member -MemberType NoteProperty -Name "imageRegistry" -Value $imageRegistry
    $sharedServices | Add-Member -MemberType NoteProperty -Name "storageMounts" -Value $storageMounts
    return $sharedServices
}

function Get-ImageVersionId ($imageGalleryResourceGroupName, $imageGalleryName, $imageDefinitionName, $imageTemplateName) {
    $imageVersions = (az sig image-version list --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
    foreach ($imageVersion in $imageVersions) {
        if ($imageVersion.tags.imageTemplateName -eq $imageTemplateName) {
            return $imageVersion.id
        }
    }
}

function Get-FileSystemMount ($mount) {
    $fsMount = $mount.exportHost + ":" + $mount.exportPath
    $fsMount += " " + $mount.directoryPath
    $fsMount += " " + $mount.fileSystemType
    $fsMount += " " + $mount.fileSystemOptions + " 0 0"
    $fsMount += " # " + $mount.fileSystemDrive
    return $fsMount
}

function Get-FileSystemMounts ([object[]] $storageMounts, [object[]] $cacheMounts) {
    $fsMounts = ""
    $fsMountDelimiter = ";"
    foreach ($storageMount in $storageMounts) {
        if ($fsMounts -ne "") {
            $fsMounts += $fsMountDelimiter
        }
        $fsMount = Get-FileSystemMount $storageMount
        $fsMounts += $fsMount
    }
    foreach ($cacheMount in $cacheMounts) {
        if ($fsMounts -ne "") {
            $fsMounts += $fsMountDelimiter
        }
        $fsMount = Get-FileSystemMount $cacheMount
        $fsMounts += $fsMount
    }
    return $fsMounts
}

function Get-CompressedData ($uncompressedData) {
    $memoryStream = New-Object System.IO.MemoryStream
    $compressionStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
    $streamWriter = New-Object System.IO.StreamWriter($compressionStream)
    $streamWriter.Write($uncompressedData)
    $streamWriter.Close();
    return $memoryStream.ToArray()
}

function Get-ScriptCommands ($scriptFile, $scriptParameters) {
    $script = Get-Content $scriptFile -Raw
    if ($scriptParameters) { # PowerShell
        $script = "& {" + $script + "} " + $scriptParameters
        $scriptCommands = [System.Text.Encoding]::Unicode.GetBytes($script)
    } else {
        $scriptCommands = Get-CompressedData($script)
    }
    return [Convert]::ToBase64String($scriptCommands)
}
