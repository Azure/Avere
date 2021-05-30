#!/bin/bash

computeRegionName=""    # List available regions via Azure CLI (az account list-locations --query [].name)
resourceGroupPrefix=""  # Alphanumeric characters, periods, underscores, hyphens and parentheses allowed

computeNetworkName=""
networkResourceGroupName=""

managedIdentityName=""
managedIdentityResourceGroupName=""

imageBuilderStorageAccountName=""
imageBuilderStorageContainerName=""

renderManagerHost=""

modulePath=$(pwd)
rootDirectory="$modulePath/.."
moduleDirectory="$(basename $(pwd))"
source "$rootDirectory/Functions.sh"

# (14) Artist Workstation Image Template
moduleName="(14) Artist Workstation Image Template"
New-TraceMessage "$moduleName" false

Set-StorageScripts $rootDirectory $moduleDirectory $imageBuilderStorageAccountName $imageBuilderStorageContainerName

templateResourcesPath="$modulePath/14.Image.json"
templateParametersPath="$modulePath/14.Image.Parameters.json"

Set-OverrideParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-OverrideParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-OverrideParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-OverrideParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Gallery")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

imageTemplates=$(Get-PropertyValue "$groupDeployment" .properties.outputs.imageTemplates.value true)
imageGallery=$(Get-PropertyValue "$groupDeployment" .properties.outputs.imageGallery.value true)

New-TraceMessage "$moduleName" true

# (14) Artist Workstation Image Build
moduleName="(14) Artist Workstation Image Build"
Build-ImageTemplates "$moduleName" $computeRegionName $imageTemplates $imageGallery

# (15) Artist Workstation Machine
moduleName="(15) Artist Workstation Machine"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/15.Machine.json"
templateParametersPath="$modulePath/15.Machine.Parameters.json"

Set-OverrideParameter $templateParametersPath "managedIdentity" "name" $managedIdentityName
Set-OverrideParameter $templateParametersPath "managedIdentity" "resourceGroupName" $managedIdentityResourceGroupName

Set-OverrideParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
Set-OverrideParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

Set-OverrideParameter $templateParametersPath "customExtension" "scriptParameters.renderManagerHost" $renderManagerHost

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Workstation")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

artistWorkstations=$(Get-PropertyValue "$groupDeployment" .properties.outputs.artistWorkstations.value true)

New-TraceMessage "$moduleName" true
