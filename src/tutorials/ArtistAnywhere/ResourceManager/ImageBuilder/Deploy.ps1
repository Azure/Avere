param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS" # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $managedIdentity = @{       # https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
        "name" = "ImageBuilder"
        "resourceGroupName" = $resourceGroup.name
    },
    $scriptStorage = @{         # https://docs.microsoft.com/azure/storage/common/storage-account-overview
        "accountName" = ""
        "containerName" = ""
        "resourceGroupName" = $resourceGroup.name
    },
    $imageTemplates = @(        # https://docs.microsoft.com/azure/virtual-machines/image-builder-overview
        @{
            "name" = ""
            "machineSize" = "Standard_NV12s_v3"
            "imageSource" = @{
                "type" = "PlatformImage"
                "publisher" = "OpenLogic"
                "offer" = "CentOS"
                "sku" = "7_9"
                "version" = "latest"
            }
            "imageBuild" = @{
                "timeoutMinutes" = 90
                "customizeCommands" = @(
                    @{
                        "type" = ""
                        "scriptUri" = ""
                        "sha256Checksum" = ""
                    }
                )
            }
            "imageGallery" = @{
                "imageDefinitionName" = ""  # Optional image distribution target
                "imageOutputVersion"= "1.0.0"
            }
        },
        @{
            "name" = ""
            "machineSize" = "Standard_NV12s_v3"
            "imageSource" = @{
                "type" = "PlatformImage"
                "publisher" = "MicrosoftWindowsDesktop" # MicrosoftWindowsServer
                "offer" = "Windows-10"                  # WindowsServer
                "sku" = "20H2-Pro"                      # 2019-Datacenter
                "version" = "latest"
            }
            "imageBuild" = @{
                "timeoutMinutes" = 90
                "customizeCommands" = @(
                    @{
                        "type" = ""
                        "scriptUri" = ""
                        "sha256Checksum" = ""
                    }
                )
            }
            "imageGallery" = @{
                "imageDefinitionName" = ""  # Optional image distribution target
                "imageOutputVersion"= "1.0.0"
            }
        }
    ),
    $imageGallery = @{  # https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries
        "name" = ""     # Optional image distribution target
        "resourceGroupName" = $resourceGroup.name
    }
)

function Set-RoleAssignment ($roleId, $principalId, $principalType, $scopeId, $scopeResourceGroup) {
    $retryCount = 0
    $roleAssigned = $false
    do {
        Write-Host "Set-RoleAssignment $roleId $principalId $principalType $scopeId"
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
}

function Set-ScriptFile ($scriptStorage, $scriptFile) {
    $retryCount = 0
    $blobUploaded = $false
    do {
        Write-Host "Set-ScriptFile $scriptFile"
        $blobUpload = (az storage blob upload --account-name $scriptStorage.accountName --container-name $scriptStorage.containerName --file "$PSScriptRoot/$scriptFile" --name $scriptFile --auth-mode login) | ConvertFrom-Json
        if ($blobUpload) {
            $blobUploaded = $true
        } else {
            $retryCount++
            Start-Sleep -Seconds 60
        }
    } while (!$blobUploaded -and $retryCount -lt 3)
}

az group create --name $resourceGroup.name --location $resourceGroup.regionName

if ($scriptStorage.accountName -ne "") {
    az storage account create --resource-group $scriptStorage.resourceGroupName --name $scriptStorage.accountName
    az storage container create --account-name $scriptStorage.accountName --name $scriptStorage.containerName --auth-mode login
}

$managedIdentityId = az identity create --resource-group $managedIdentity.resourceGroupName --name $managedIdentity.name --query "principalId" --output "tsv"

$currentUserId = az ad signed-in-user show --query "objectId" --output "tsv"

if ($scriptStorage.accountName -ne "") {
    $storageAccountId = az storage account show --name $scriptStorage.accountName --query "id" --output "tsv"

    $roleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Object Data Contributor
    Set-RoleAssignment $roleId $currentUserId "User" $storageAccountId $false

    $roleId = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" # Storage Object Data Reader
    Set-RoleAssignment $roleId $managedIdentityId "ServicePrincipal" $storageAccountId $false

    $roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
    Set-RoleAssignment $roleId $managedIdentityId "ServicePrincipal" $storageAccountId $false
}

$roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
$resourceGroupName = $imageGallery.resourceGroupName -eq "" ? $resourceGroup.name : $imageGallery.resourceGroupName
Set-RoleAssignment $roleId $managedIdentityId "ServicePrincipal" $resourceGroupName $true

Start-Sleep -Seconds 180 # Role assignment replication delay

if ($scriptStorage.accountName -eq "") {
    foreach ($imageTemplate in $imageTemplates) {
        $imageTemplate.imageBuild.customizeCommands = @()
    }
} else {
    $scriptFileLinux = "Customize.sh"
    $scriptFileWindows = "Customize.ps1"

    Set-ScriptFile $scriptStorage $scriptFileLinux
    Set-ScriptFile $scriptStorage $scriptFileWindows

    foreach ($imageTemplate in $imageTemplates) {
        if ($imageTemplate.name -ne "") {
            $imageSource = (az vm image show --urn ($imageTemplate.imageSource.publisher + ":" + $imageTemplate.imageSource.offer + ":" + $imageTemplate.imageSource.sku + ":" + $imageTemplate.imageSource.version)) | ConvertFrom-Json
            if ($imageSource.osDiskImage.operatingSystem -eq "Windows") {
                $scriptType = "PowerShell"
                $scriptFile = $scriptFileWindows
            } else {
                $scriptType = "Shell"
                $scriptFile = $scriptFileLinux
            }
            $customizeCommand = $imageTemplate.imageBuild.customizeCommands[0]
            if ($customizeCommand.type -eq "") {
                $customizeCommand.type = $scriptType
            }
            if ($customizeCommand.scriptUri -eq "") {
                $scriptFileHash = Get-FileHash -Path "$PSScriptRoot/$scriptFile" -Algorithm "SHA256"
                $customizeCommand.scriptUri = "https://" + $scriptStorage.accountName + ".blob.core.windows.net/" + $scriptStorage.containerName + "/$scriptFile"
                $customizeCommand.sha256Checksum = $scriptFileHash.hash.ToLower()
            }
        }
    }
}

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.managedIdentity.value = $managedIdentity
$templateConfig.parameters.imageTemplates.value = $imageTemplates
$templateConfig.parameters.imageGallery.value = $imageGallery
$templateConfig | ConvertTo-Json -Depth 7 | Out-File $templateParameters

az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters

foreach ($imageTemplate in $imageTemplates) {
    if ($imageTemplate.name -ne "") {
        az image builder run --resource-group $resourceGroup.name --name $imageTemplate.name --no-wait
    }
}
