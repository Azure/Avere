param (
  $computeRegionName = "",    # List Azure region names via Azure CLI (az account list-locations --query [].name)
  $resourceGroupPrefix = "",  # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid

  $computeNetworkName = "",
  $networkResourceGroupName = "",

  $managedIdentityName = "",
  $managedIdentityResourceGroupName = "",

  $imageBuilderStorageAccountName = "",
  $imageBuilderStorageContainerName = ""
)

$modulePath = $PSScriptRoot
$rootDirectory = "$modulePath/.."
$moduleDirectory = (Get-Item -Path $modulePath).Name
Import-Module "$rootDirectory/Functions.psm1"

# (09) Render Manager Database
$moduleName = "(09) Render Manager Database"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/09.Database.json"
$templateParametersPath = "$modulePath/09.Database.Parameters.json"

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Manager"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$dataTierHost = $groupDeployment.properties.outputs.dataTierHost.value
$dataTierPort = $groupDeployment.properties.outputs.dataTierPort.value
$dataTierAdminUsername = $groupDeployment.properties.outputs.dataTierAdminUsername.value
$dataTierAdminPassword = $groupDeployment.properties.outputs.dataTierAdminPassword.value

New-TraceMessage $moduleName $true

# (10) Render Manager Image Template
$moduleName = "(10) Render Manager Image Template"
New-TraceMessage $moduleName $false

Set-StorageScripts $rootDirectory $moduleDirectory $imageBuilderStorageAccountName $imageBuilderStorageContainerName

$templateResourcesPath = "$modulePath/10.Image.json"
$templateParametersPath = "$modulePath/10.Image.Parameters.json"

Set-TemplateParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-TemplateParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Gallery"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$imageTemplates = $groupDeployment.properties.outputs.imageTemplates.value
$imageGallery = $groupDeployment.properties.outputs.imageGallery.value

New-TraceMessage $moduleName $true

# (10) Render Manager Image Build
$moduleName = "(10) Render Manager Image Build"
Build-ImageTemplates $moduleName $computeRegionName $imageTemplates $imageGallery

# (11) Render Manager Machine
$moduleName = "(11) Render Manager Machine"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/11.Machine.json"
$templateParametersPath = "$modulePath/11.Machine.Parameters.json"

Set-TemplateParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-TemplateParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierHost" $dataTierHost
Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierPort" $dataTierPort
Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierAdminUsername" $dataTierAdminUsername
Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierAdminPassword" $dataTierAdminPassword

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Manager"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$renderManagers = $groupDeployment.properties.outputs.renderManagers.value

New-TraceMessage $moduleName $true
