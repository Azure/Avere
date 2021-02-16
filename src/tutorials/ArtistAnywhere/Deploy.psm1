function New-TraceMessage ($moduleName, $moduleEnd) {
    $traceMessage = Get-Date -Format "hh:mm:ss"
    $traceMessage += " $moduleName"
    if ($moduleName -notMatch "Assignment|Build|Upload|Job") {
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
    $retryCount = 0
    $roleAssigned = $false
    do {
        if ($scopeResourceGroup) {
            $roleAssignment = (az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --resource-group $scopeId) | ConvertFrom-Json
        } else {
            $roleAssignment = (az role assignment create --role $roleId --assignee-object-id $principalId --assignee-principal-type $principalType --scope $scopeId) | ConvertFrom-Json
        }
        if ($roleAssignment) {
            $roleAssigned = $true
        } else {
            $retryCount++
        }
    } while (!$roleAssigned -and $retryCount -lt 3)
    if ($assignmentPropagationWait) {
        Start-Sleep -Seconds 180
    }
}

function Set-RoleAssignments ($moduleType, $storageAccountName, $computeNetwork, $managedIdentity, $keyVault, $imageGallery, $eventGridTopicId) {
    switch ($moduleType) {
        "Key Vault" {
            $principalType = "User"
            $userId = az ad signed-in-user show --query "objectId" --output "tsv"
            $roleId = "00482a5a-887f-4fb3-b363-3b7fe8e74483" # Key Vault Admnistrator
            Set-RoleAssignment $roleId $userId $principalType $keyVault.id $false $false
        }
        "Storage" {
            $userId = az ad signed-in-user show --query "objectId" --output "tsv"
            $storageId = az storage account show --name $storageAccountName --query "id" --output "tsv"

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
        }
        "Image Builder" {
            $principalType = "ServicePrincipal"

            $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
            Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $imageGallery.resourceGroupName $true $false

            $roleId = "9980e02c-c2be-4d73-94e8-173b1dc7cf3c" # Virtual Machine Contributor
            Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $computeNetwork.resourceGroupName $true $false
        }
        "CycleCloud" {
            $principalType = "ServicePrincipal"

            $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
            $subscriptionId = az account show --query "id" --output "tsv"
            Set-RoleAssignment $roleId $managedIdentity.principalId $principalType "/subscriptions/$subscriptionId" $false $false

            $roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
            Set-RoleAssignment $roleId $managedIdentity.principalId $principalType $eventGridTopicId $false $false
         }
        "Batch" {
            $principalType = "ServicePrincipal"

            $principalId = "f520d84c-3fd3-4cc8-88d4-2ed25b00d27a" # Microsoft Azure Batch
            $roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"      # Contributor

            $subscriptionId = az account show --query "id" --output "tsv"
            $subscriptionId = "/subscriptions/$subscriptionId"

            Set-RoleAssignment $roleId $principalId $principalType $subscriptionId $false $false

            az keyvault update --resource-group $keyVault.resourceGroupName --name $keyVault.name --enable-rbac-authorization $false --output none --only-show-errors
            az keyvault set-policy --resource-group $keyVault.resourceGroupName --name $keyVault.name --object-id $principalId --secret-permissions Get List Set Delete --output none
            az keyvault update --resource-group $keyVault.resourceGroupName --name $keyVault.name --enable-rbac-authorization $true --output none --only-show-errors
        }
    }
}

function Get-ImageCustomizeCommand ($rootDirectory, $moduleDirectory, $storageAccount, $osType, $scriptFile) {
    $commandType = "File"
    $scriptDirectory = $moduleDirectory
    switch ($osType) {
        "Linux" {
            $commandType = "Shell"
            $scriptDirectory += "/Linux"
            $scriptFile = "$scriptFile.sh"
            $downloadsPath = "/tmp/"
        }
        "Windows" {
            $commandType = "PowerShell"
            $scriptDirectory += "/Windows"
            $scriptFile = "$scriptFile.ps1"
            $downloadsPath = "C:\Windows\Temp\"
        }
    }

    $scriptUri = "https://" + $storageAccount.name + ".blob.core.windows.net/script/$scriptDirectory/$scriptFile"
    $scriptFileHash = Get-FileHash -Path "$rootDirectory/$scriptDirectory/$scriptFile" -Algorithm "SHA256"

    $customizeCommand = New-Object PSObject
    $customizeCommand | Add-Member -MemberType NoteProperty -Name "type" -Value $commandType
    if ($commandType -eq "File") {
        $customizeCommand | Add-Member -MemberType NoteProperty -Name "sourceUri" -Value $scriptUri
        $customizeCommand | Add-Member -MemberType NoteProperty -Name "destination" -Value "$downloadsPath$scriptFile"
    } else {
        $customizeCommand | Add-Member -MemberType NoteProperty -Name "scriptUri" -Value $scriptUri
    }
    $customizeCommand | Add-Member -MemberType NoteProperty -Name "sha256Checksum" -Value $scriptFileHash.hash.ToLower()
    return $customizeCommand
}

function Get-ImageVersion ($imageGallery, $imageTemplate) {
    $imageVersions = (az sig image-version list --resource-group $imageGallery.resourceGroupName --gallery-name $imageGallery.name --gallery-image-definition $imageTemplate.imageDefinitionName) | ConvertFrom-Json
    foreach ($imageVersion in $imageVersions) {
        if ($imageVersion.tags.imageTemplateName -eq $imageTemplate.name) {
            return $imageVersion
        }
    }
}

function Set-ImageTemplates ($resourceGroupName, $templateParameters, $osTypes) {
    $templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
    foreach ($imageTemplate in $templateConfig.parameters.imageTemplates.value) {
        if ($imageTemplate.imageOperatingSystemType -in $osTypes) {
            az image builder delete --resource-group $resourceGroupName --name $imageTemplate.name --output none
            $imageTemplate.deploy = $true
        }
    }
    return $templateConfig
}

function Build-ImageTemplates ($moduleName, $computeRegionName, $imageGallery, $imageTemplates) {
    New-TraceMessage $moduleName $false
    foreach ($imageTemplate in $imageTemplates) {
        if ($imageTemplate.deploy) {
            $imageVersion = Get-ImageVersion $imageGallery $imageTemplate
            if (!$imageVersion) {
                New-TraceMessage "$moduleName [$($imageTemplate.name)]" $false
                az image builder run --resource-group $resourceGroupName --name $imageTemplate.name --output none
                New-TraceMessage "$moduleName [$($imageTemplate.name)]" $true
            }
        }
    }
    New-TraceMessage $moduleName $true
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
