#!/bin/bash

computeRegionName=""        # List Azure region names via Azure CLI (az account list-locations --query [].name)
storageRegionName=""        # List Azure region names via Azure CLI (az account list-locations --query [].name)
resourceGroupPrefix=""      # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid
enableNetworkGateway=false  # https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways

modulePath=$(pwd)
source "$modulePath/../Functions.sh"

# (00) Monitor Telemetry
moduleName="(00) Monitor Telemetry"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/00.MonitorTelemetry.json"
templateParametersPath="$modulePath/00.MonitorTelemetry.Parameters.json"

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix "")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

logAnalytics=$(Get-PropertyValue "$groupDeployment" .properties.outputs.logAnalytics.value true)
appInsights=$(Get-PropertyValue "$groupDeployment" .properties.outputs.appInsights.value true)

New-TraceMessage "$moduleName" true

# (01) Virtual Network
moduleName="(01) Virtual Network"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/01.VirtualNetwork.json"
templateParametersPath="$modulePath/01.VirtualNetwork.Parameters.json"

Set-TemplateParameter $templateParametersPath "computeNetwork" "regionName" $computeRegionName
Set-TemplateParameter $templateParametersPath "storageNetwork" "regionName" $storageRegionName

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Network")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

computeNetwork=$(Get-PropertyValue "$groupDeployment" .properties.outputs.computeNetwork.value true)
storageNetwork=$(Get-PropertyValue "$groupDeployment" .properties.outputs.storageNetwork.value true)

New-TraceMessage "$moduleName" true

# (02) Managed Identity
moduleName="(02) Managed Identity"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/02.ManagedIdentity.json"
templateParametersPath="$modulePath/02.ManagedIdentity.Parameters.json"

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix "")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

managedIdentity=$(Get-PropertyValue "$groupDeployment" .properties.outputs.managedIdentity.value true)

New-TraceMessage "$moduleName" true

# (03) Key Vault
moduleName="(03) Key Vault"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/03.KeyVault.json"
templateParametersPath="$modulePath/03.KeyVault.Parameters.json"

principalId=$(az ad signed-in-user show --query objectId --output tsv)
Set-TemplateParameter $templateParametersPath "keyVault" "adminUserPrincipalId" $principalId

principalId=$(Get-PropertyValue $managedIdentity .principalId true)
Set-TemplateParameter $templateParametersPath "keyVault" "managedIdentityPrincipalId" $principalId

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" "$computeNetwork" .name
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" "$computeNetwork" .resourceGroupName

resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix "")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

keyVault=$(Get-PropertyValue "$groupDeployment" .properties.outputs.keyVault.value true)

New-TraceMessage "$moduleName" true

# (04) Network Gateway
if [ $enableNetworkGateway == true ]; then
  moduleName="(04) Network Gateway"
  New-TraceMessage "$moduleName" false

  templateResourcesPath="$modulePath/04.NetworkGateway.json"
  templateParametersPath="$modulePath/04.NetworkGateway.Parameters.json"

  Set-TemplateParameter $templateParametersPath "computeNetwork" "name" "$computeNetwork" .name
  Set-TemplateParameter $templateParametersPath "computeNetwork" "resourceGroupName" "$computeNetwork" .resourceGroupName
  Set-TemplateParameter $templateParametersPath "computeNetwork" "regionName" "$computeNetwork" .regionName

  Set-TemplateParameter $templateParametersPath "storageNetwork" "name" "$storageNetwork" .name
  Set-TemplateParameter $templateParametersPath "storageNetwork" "resourceGroupName" "$storageNetwork" .resourceGroupName
  Set-TemplateParameter $templateParametersPath "storageNetwork" "regionName" "$storageNetwork" .regionName

  keyName="networkConnectionKey"
  keyVaultId=$(Get-PropertyValue "$keyVault" .id true)
  Set-TemplateParameter $templateParametersPath $keyName "keyVault.id" $keyVaultId
  Set-TemplateParameter $templateParametersPath $keyName "secretName" $keyName

  resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Network")
  groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath)

  New-TraceMessage "$moduleName" true
fi
