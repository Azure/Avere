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

function Get-ImageVersionId ($imageGalleryResourceGroupName, $imageGalleryName, $imageDefinitionName, $imageTemplateName) {
    $imageVersions = (az sig image-version list --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
    foreach ($imageVersion in $imageVersions) {
        if ($imageVersion.tags.imageTemplate -eq $imageTemplateName) {
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
    $fsMount += " " + $mount.directoryPermissions
    return $fsMount
}

function Get-StorageMountCommands ($imageGallery, $imageDefinitionName, $storageMounts) {
    $mountCommands = @()
    $imageDefinition = (az sig image-definition show --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageDefinitionName) | ConvertFrom-Json
    if ($imageDefinition.osType -eq "Windows") {
        foreach ($storageMount in $storageMounts) {
            $mountCommand = "New-PSDrive -Name " + $storageMount.fileSystemDrive + " -PSProvider FileSystem"
            $mountCommand += " -Root \\" + $storageMount.exportHost + $storageMount.exportPath.Replace('/', '\')
            $mountCommand += " -Scope Global -Persist"
            $mountCommands += $mountCommand
        }
    } else {
        foreach ($storageMount in $storageMounts) {
            $mountCommands += "mkdir -p " + $storageMount.directoryPath
            $mountCommand = "mount -t " + $storageMount.fileSystemType + " -o " + $storageMount.fileSystemOptions
            $mountCommand += " " + $storageMount.exportHost + ":" + $storageMount.exportPath
            $mountCommand += " " + $storageMount.directoryPath
            $mountCommands += $mountCommand
        }
    }
    return $mountCommands
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

function Get-ScriptCommands ($scriptFile, $scriptParameters) {
    $script = Get-Content $scriptFile -Raw
    if ($scriptParameters) { # PowerShell
        $script = "& {" + $script + "} " + $scriptParameters
        $scriptCommands = [System.Text.Encoding]::Unicode.GetBytes($script)
    } else {
        $memoryStream = New-Object System.IO.MemoryStream
        $compressionStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
        $streamWriter = New-Object System.IO.StreamWriter($compressionStream)
        $streamWriter.Write($script)
        $streamWriter.Close();
        $scriptCommands = $memoryStream.ToArray()    
    }
    return [Convert]::ToBase64String($scriptCommands)
}
