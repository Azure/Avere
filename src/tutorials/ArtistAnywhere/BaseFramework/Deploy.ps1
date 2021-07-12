param (
  $computeRegionName = "",        # List Azure region names via Azure CLI (az account list-locations --query [].name)
  $storageRegionName = "",        # List Azure region names via Azure CLI (az account list-locations --query [].name)
  $resourceGroupPrefix = "",      # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid
  $enableNetworkGateway = $false  # https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways
)

$modulePath = $PSScriptRoot
Import-Module "$modulePath/../Functions.psm1"

# (00) Monitor Telemetry
$moduleName = "(00) Monitor Telemetry"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/00.MonitorTelemetry.json"
$templateParametersPath = "$modulePath/00.MonitorTelemetry.Parameters.json"

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ""
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$logAnalytics = $groupDeployment.properties.outputs.logAnalytics.value
$appInsights = $groupDeployment.properties.outputs.appInsights.value

New-TraceMessage $moduleName $true

# (01) Virtual Network
$moduleName = "(01) Virtual Network"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/01.VirtualNetwork.json"
$templateParametersPath = "$modulePath/01.VirtualNetwork.Parameters.json"

Set-TemplateParameter $templateParametersPath "computeNetwork" "regionName" $computeRegionName
Set-TemplateParameter $templateParametersPath "storageNetwork" "regionName" $storageRegionName

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Network"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$computeNetwork = $groupDeployment.properties.outputs.computeNetwork.value
$storageNetwork = $groupDeployment.properties.outputs.storageNetwork.value

New-TraceMessage $moduleName $true

# (02) Managed Identity
$moduleName = "(02) Managed Identity"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/02.ManagedIdentity.json"
$templateParametersPath = "$modulePath/02.ManagedIdentity.Parameters.json"

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ""
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$managedIdentity = $groupDeployment.properties.outputs.managedIdentity.value

New-TraceMessage $moduleName $true

# (03) Key Vault
$moduleName = "(03) Key Vault"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/03.KeyVault.json"
$templateParametersPath = "$modulePath/03.KeyVault.Parameters.json"

$principalId = az ad signed-in-user show --query objectId --output tsv
Set-TemplateParameter $templateParametersPath "keyVault" "adminUserPrincipalId" $principalId
Set-TemplateParameter $templateParametersPath "keyVault" "managedIdentityPrincipalId" $managedIdentity.principalId

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetwork.name
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $computeNetwork.resourceGroupName

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ""
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$keyVault = $groupDeployment.properties.outputs.keyVault.value

New-TraceMessage $moduleName $true

# (04) Network Gateway
if ($enableNetworkGateway) {
  $moduleName = "(04) Network Gateway"
  New-TraceMessage $moduleName $false

  $templateResourcesPath = "$modulePath/04.NetworkGateway.json"
  $templateParametersPath = "$modulePath/04.NetworkGateway.Parameters.json"

  Set-TemplateParameter $templateParametersPath "computeNetwork" "name" $computeNetwork.name
  Set-TemplateParameter $templateParametersPath "computeNetwork" "resourceGroupName" $computeNetwork.resourceGroupName
  Set-TemplateParameter $templateParametersPath "computeNetwork" "regionName" $computeNetwork.regionName

  Set-TemplateParameter $templateParametersPath "storageNetwork" "name" $storageNetwork.name
  Set-TemplateParameter $templateParametersPath "storageNetwork" "resourceGroupName" $storageNetwork.resourceGroupName
  Set-TemplateParameter $templateParametersPath "storageNetwork" "regionName" $storageNetwork.regionName

  $keyName = "networkConnectionKey"
  $keyVaultRef = New-Object PSObject
  $keyVaultRef | Add-Member -MemberType NoteProperty -Name "id" -Value $keyVault.id
  Set-TemplateParameter $templateParametersPath $keyName "keyVault" $keyVaultRef
  Set-TemplateParameter $templateParametersPath $keyName "secretName" $keyName

  $resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Network"
  $groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

  New-TraceMessage $moduleName $true
}
