#!/bin/bash

computeRegionName=""    # List Azure region names via Azure CLI (az account list-locations --query [].name)
resourceGroupPrefix=""  # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid

computeNetworkName=""
networkResourceGroupName=""

managedIdentityName=""
managedIdentityResourceGroupName=""

imageBuilderStorageAccountName=""
imageBuilderStorageContainerName=""

modulePath=$(pwd)
rootDirectory="$modulePath/.."
moduleDirectory="$(basename $(pwd))"
source "$rootDirectory/Functions.sh"

# (09) Render Manager Database
moduleName="(09) Render Manager Database"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/09.Database.json"
templateParametersPath="$modulePath/09.Database.Parameters.json"

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Manager")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

dataTierHost=$(Get-PropertyValue "$groupDeployment" .properties.outputs.dataTierHost.value)
dataTierPort=$(Get-PropertyValue "$groupDeployment" .properties.outputs.dataTierPort.value)
dataTierAdminUsername=$(Get-PropertyValue "$groupDeployment" .properties.outputs.dataTierAdminUsername.value)
dataTierAdminPassword=$(Get-PropertyValue "$groupDeployment" .properties.outputs.dataTierAdminPassword.value)

New-TraceMessage "$moduleName" true

# (10) Render Manager Image Template
moduleName="(10) Render Manager Image Template"
New-TraceMessage "$moduleName" false

Set-StorageScripts $rootDirectory $moduleDirectory $imageBuilderStorageAccountName $imageBuilderStorageContainerName

templateResourcesPath="$modulePath/10.Image.json"
templateParametersPath="$modulePath/10.Image.Parameters.json"

Set-TemplateParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-TemplateParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Gallery")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

imageTemplates=$(Get-PropertyValue "$groupDeployment" .properties.outputs.imageTemplates.value true)
imageGallery=$(Get-PropertyValue "$groupDeployment" .properties.outputs.imageGallery.value true)

New-TraceMessage "$moduleName" true

# (10) Render Manager Image Build
moduleName="(10) Render Manager Image Build"
Build-ImageTemplates "$moduleName" $computeRegionName $imageTemplates $imageGallery

# (11) Render Manager Machine
moduleName="(11) Render Manager Machine"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/11.Machine.json"
templateParametersPath="$modulePath/11.Machine.Parameters.json"

Set-TemplateParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-TemplateParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierHost" $dataTierHost
Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierPort" $dataTierPort
Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierAdminUsername" $dataTierAdminUsername
Set-TemplateParameter $templateParametersPath "customExtension" "scriptParameters.dataTierAdminPassword" $dataTierAdminPassword

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Manager")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

renderManagers=$(Get-PropertyValue "$groupDeployment" .properties.outputs.renderManagers.value true)

New-TraceMessage "$moduleName" true
