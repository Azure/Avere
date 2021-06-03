param (
  $computeRegionName = "",    # List available regions via Azure CLI (az account list-locations --query [].name)
  $storageRegionName = "",    # List available regions via Azure CLI (az account list-locations --query [].name)
  $resourceGroupPrefix = "",  # Alphanumeric characters, periods, underscores, hyphens and parentheses allowed

  $computeNetworkName = "",
  $storageNetworkName = "",
  $networkResourceGroupName = "",

  $managedIdentityName = "",
  $managedIdentityResourceGroupName = "",

  $enableHPCCache = $false
)

$modulePath = $PSScriptRoot
$rootDirectory = "$modulePath/.."
$moduleDirectory = (Get-Item -Path $modulePath).Name
Import-Module "$rootDirectory/Functions.psm1"

function Set-MountUnitFile ($outputDirectory, $mount) {
  $outputFileName = $mount.path.Substring(1).Replace('/', '-')
  $outputFilePath = "$outputDirectory/$outputFileName.mount"
  Out-File -FilePath $outputFilePath -InputObject "[Unit]"
  Out-File -FilePath $outputFilePath -InputObject "After=network-online.target" -Append
  Out-File -FilePath $outputFilePath -InputObject "" -Append
  Out-File -FilePath $outputFilePath -InputObject "[Mount]" -Append
  Out-File -FilePath $outputFilePath -InputObject ("Type=" + $mount.type) -Append
  Out-File -FilePath $outputFilePath -InputObject ("What=" + $mount.host) -Append
  Out-File -FilePath $outputFilePath -InputObject ("Where=" + $mount.path) -Append
  Out-File -FilePath $outputFilePath -InputObject ("Options=" + $mount.options) -Append
  Out-File -FilePath $outputFilePath -InputObject "" -Append
  Out-File -FilePath $outputFilePath -InputObject "[Install]" -Append
  Out-File -FilePath $outputFilePath -InputObject "WantedBy=multi-user.target" -Append
}

# (05) Storage
$moduleName = "(05) Storage"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/05.Storage.json"
$templateParametersPath = "$modulePath/05.Storage.Parameters.json"

Set-OverrideParameter $templateParametersPath "virtualNetwork" "name" $storageNetworkName
Set-OverrideParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

$resourceGroupName = Set-ResourceGroup $storageRegionName $resourceGroupPrefix ".Storage"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$storageAccounts = $groupDeployment.properties.outputs.storageAccounts.value
$storageMounts = $groupDeployment.properties.outputs.storageMounts.value
$storageTargets = $groupDeployment.properties.outputs.storageTargets.value

foreach ($storageMount in $storageMounts) {
  Set-MountUnitFile $modulePath $storageMount
}

New-TraceMessage $moduleName $true

if ($enableHPCCache) {
  # (06) HPC Cache
  $moduleName = "(06) HPC Cache"
  New-TraceMessage $moduleName $false

  $templateResourcesPath = "$modulePath/06.HPCCache.json"
  $templateParametersPath = "$modulePath/06.HPCCache.Parameters.json"

  Set-OverrideParameter $templateParametersPath "storageTargets" "" $storageTargets
  Set-OverrideParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
  Set-OverrideParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

  $resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Cache"
  $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

  $hpcCache = $groupDeployment.properties.outputs.hpcCache.value

  New-TraceMessage $moduleName $true

  # (06) HPC Cache DNS
  $moduleName = "(06) HPC Cache DNS"
  New-TraceMessage $moduleName $false

  $templateResourcesPath = "$modulePath/06.HPCCache.DNS.json"
  $templateParametersPath = "$modulePath/06.HPCCache.DNS.Parameters.json"

  Set-OverrideParameter $templateParametersPath "hpcCache" "" $hpcCache
  Set-OverrideParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
  Set-OverrideParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

  $resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Cache"
  $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

  $hpcCacheMounts = $groupDeployment.properties.outputs.hpcCacheMounts.value

  foreach ($cacheMount in $hpcCacheMounts) {
    Set-MountUnitFile $modulePath $cacheMount
  }

  New-TraceMessage $moduleName $true
}

# (**) Mount Unit Files
$moduleName = "(**) Mount Unit Files"
New-TraceMessage $moduleName $false

$storageAccount = $storageAccounts[0]
$storageContainerName = "script"
$mountFilePattern = "*.mount"

$sourceDirectory = "$rootDirectory/$moduleDirectory"
$destinationDirectory = "$storageContainerName/$moduleDirectory"
az storage blob upload-batch --account-name $storageAccount.name --destination $destinationDirectory --source $sourceDirectory --pattern "$mountFilePattern" --auth-mode login --output none --no-progress

New-TraceMessage $moduleName $true
