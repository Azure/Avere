#!/bin/bash

computeRegionName=""    # List Azure region names via Azure CLI (az account list-locations --query [].name)
resourceGroupPrefix=""  # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid

computeNetworkName=""
networkResourceGroupName=""

managedIdentityName=""
managedIdentityResourceGroupName=""

modulePath=$(pwd)
source "$modulePath/../Functions.sh"

# (07) Image Gallery
moduleName="(07) Image Gallery"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/07.ImageGallery.json"
templateParametersPath="$modulePath/07.ImageGallery.Parameters.json"

principalId=$(az identity show --resource-group $managedIdentityResourceGroupName --name $managedIdentityName --query principalId --output tsv)
Set-TemplateParameter $templateParametersPath "imageGallery" "managedIdentityPrincipalId" $principalId
Set-TemplateParameter $templateParametersPath "imageGallery" "networkResourceGroupName" $networkResourceGroupName

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Gallery")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

imageGallery=$(Get-PropertyValue "$groupDeployment" .properties.outputs.imageGallery.value true)

New-TraceMessage "$moduleName" true

# (08) Container Registry
moduleName="(08) Container Registry"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/08.ContainerRegistry.json"
templateParametersPath="$modulePath/08.ContainerRegistry.Parameters.json"

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Registry")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

containerRegistry=$(Get-PropertyValue "$groupDeployment" .properties.outputs.containerRegistry.value true)

New-TraceMessage "$moduleName" true
