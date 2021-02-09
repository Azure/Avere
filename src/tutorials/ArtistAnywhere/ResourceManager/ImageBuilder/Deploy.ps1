param (
    $resourceGroup = @{
        "name" = ""
        "regionName" = "WestUS2"    # https://azure.microsoft.com/global-infrastructure/geographies/
    },
    $imageTemplate = @{             # https://docs.microsoft.com/azure/virtual-machines/image-builder-overview
        "name" = ""
        "machineType" = "Linux"
        "machineSize" = "Standard_HB120rs_v2"
        "imageSourceType" = "PlatformImage"
        "imageSourceVersion" = "latest"
        "imageOutputVersion" = "1.0.0"
        "buildTimeoutMinutes" = 120
        "buildCustomizeCommands" = @(
            @{
                "type" = ""
                "scriptUri" = ""
                "sha256Checksum" = ""
            }
        )
    },
    $imageGallery = @{              # https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries
        "name" = ""
        "resourceGroupName" = ""
        "imageDefinitionName" = ""
    },
    $storageAccount = @{            # https://docs.microsoft.com/azure/storage/common/storage-account-overview
        "name" = ""
        "containerName" = ""
    },
    $managedIdentity = @{           # https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
        "name" = $imageTemplate.Name
        "resourceGroupName" = $resourceGroup.name
    }
)

$currentUserId = az ad signed-in-user show --query "objectId"
$storageAccountId = az storage account show --name $storageAccount.name --query "id"
$managedIdentityId = az identity create --resource-group $managedIdentity.resourceGroupName --name $managedIdentity.name --query "principalId"

$roleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Object Data Contributor
az role assignment create --scope $storageAccountId --role $roleId --assignee-object-id $currentUserId --assignee-principal-type "User"

$roleId = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" # Storage Object Data Reader
az role assignment create --scope $storageAccountId --role $roleId --assignee-object-id $managedIdentityId --assignee-principal-type "ServicePrincipal"

$roleId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader
az role assignment create --scope $storageAccountId --role $roleId --assignee-object-id $managedIdentityId --assignee-principal-type "ServicePrincipal"

$roleId = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
az role assignment create --resource-group $imageGallery.resourceGroupName --role $roleId --assignee-object-id $managedIdentityId --assignee-principal-type "ServicePrincipal"

$scriptFileLinux = "Customize.sh"
$scriptFileWindows = "Customize.ps1"

az storage container create --account-name $storageAccount.name --name $storageAccount.containerName --auth-mode login
az storage blob upload --account-name $storageAccount.name --container-name $storageAccount.containerName --file "$PSScriptRoot/$scriptFileLinux" --name $scriptFileLinux --auth-mode login
az storage blob upload --account-name $storageAccount.name --container-name $storageAccount.containerName --file "$PSScriptRoot/$scriptFileWindows" --name $scriptFileWindows --auth-mode login

if ($imageTemplate.machineType -eq "Windows") {
    $scriptType = "PowerShell"
    $scriptFile = $scriptFileWindows
} else {
    $scriptType = "Shell"
    $scriptFile = $scriptFileLinux
}
if ($imageTemplate.buildCustomizeCommands[0].type -eq "") {
    $imageTemplate.buildCustomizeCommands[0].type = $scriptType
}
if ($imageTemplate.buildCustomizeCommands[0].scriptUri -eq "") {
    $scriptUri = "https://" + $storageAccount.name + ".blob.core.windows.net/" + $storageAccount.containerName + "/$scriptFile"
    $scriptFileHash = Get-FileHash -Path "$PSScriptRoot/$scriptFile" -Algorithm "SHA256"
    $imageTemplate.buildCustomizeCommands[0].scriptUri = $scriptUri
    $imageTemplate.buildCustomizeCommands[0].sha256Checksum = $scriptFileHash.hash.ToLower()
}

az group create --name $resourceGroup.name --location $resourceGroup.regionName

$templateFile = "$PSScriptRoot/Template.json"
$templateParameters = "$PSScriptRoot/Template.Parameters.json"

$templateConfig = Get-Content -Path $templateParameters -Raw | ConvertFrom-Json
$templateConfig.parameters.imageTemplate.value = $imageTemplate
$templateConfig.parameters.imageGallery.value = $imageGallery
$templateConfig.parameters.managedIdentity.value = $managedIdentity
$templateConfig | ConvertTo-Json -Depth 5 | Out-File $templateParameters

$timeFormat = "hh:mm:ss"
Write-Host (Get-Date -Format $timeFormat) "Image Template Deployment Start"
az deployment group create --resource-group $resourceGroup.name --template-file $templateFile --parameters $templateParameters
Write-Host (Get-Date -Format $timeFormat) "Image Template Deployment End"

Write-Host (Get-Date -Format $timeFormat) "Image Template Build Start"
az image builder run --resource-group $resourceGroup.name --name $imageTemplate.name
Write-Host (Get-Date -Format $timeFormat) "Image Template Build End"
