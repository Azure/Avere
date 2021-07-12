param (
  $computeRegionName = "",    # List Azure region names via Azure CLI (az account list-locations --query [].name)
  $resourceGroupPrefix = "",  # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid

  $computeNetworkName = "",
  $networkResourceGroupName = "",

  $managedIdentityName = "",
  $managedIdentityResourceGroupName = "",

  $imageBuilderStorageAccountName = "",
  $imageBuilderStorageContainerName = "",

  $renderManagerHost = ""
)

$modulePath = $PSScriptRoot
$rootDirectory = "$modulePath/.."
$moduleDirectory = (Get-Item -Path $modulePath).Name
Import-Module "$rootDirectory/Functions.psm1"

# (12) Render Farm Image Template
$moduleName = "(12) Render Farm Image Template"
New-TraceMessage $moduleName $false

Set-StorageScripts $rootDirectory $moduleDirectory $imageBuilderStorageAccountName $imageBuilderStorageContainerName

$templateResourcesPath = "$modulePath/12.Image.json"
$templateParametersPath = "$modulePath/12.Image.Parameters.json"

Set-TemplateParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-TemplateParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Gallery"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$imageTemplates = $groupDeployment.properties.outputs.imageTemplates.value
$imageGallery = $groupDeployment.properties.outputs.imageGallery.value

New-TraceMessage $moduleName $true

# (12) Render Farm Image Build
$moduleName = "(12) Render Farm Image Build"
Build-ImageTemplates $moduleName $computeRegionName $imageTemplates $imageGallery

# (13) Render Farm Scale Set
$moduleName = "(13) Render Farm Scale Set"
New-TraceMessage $moduleName $false

$templateResourcesPath = "$modulePath/13.ScaleSet.json"
$templateParametersPath = "$modulePath/13.ScaleSet.Parameters.json"

Set-TemplateParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-TemplateParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.renderManagerHost" $renderManagerHost

$resourceGroupName = Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Farm"
$groupDeployment = (az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath) | ConvertFrom-Json

$renderFarms = $groupDeployment.properties.outputs.renderFarms.value

New-TraceMessage $moduleName $true
