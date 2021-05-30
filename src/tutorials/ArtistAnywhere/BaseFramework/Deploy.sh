#!/bin/bash

computeRegionName=""        # List available regions via Azure CLI (az account list-locations --query [].name)
storageRegionName=""        # List available regions via Azure CLI (az account list-locations --query [].name)
resourceGroupPrefix=""      # Alphanumeric characters, periods, underscores, hyphens and parentheses allowed
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

Set-OverrideParameter $templateParametersPath "computeNetwork" "regionName" $computeRegionName
Set-OverrideParameter $templateParametersPath "storageNetwork" "regionName" $storageRegionName

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
Set-OverrideParameter $templateParametersPath "keyVault" "adminUserPrincipalId" $principalId

principalId=$(Get-PropertyValue $managedIdentity .principalId true)
Set-OverrideParameter $templateParametersPath "keyVault" "managedIdentityPrincipalId" $principalId

Set-OverrideParameter $templateParametersPath "virtualNetwork" "name" "$computeNetwork" .name
Set-OverrideParameter $templateParametersPath "virtualNetwork" "resourceGroupName" "$computeNetwork" .resourceGroupName

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

  Set-OverrideParameter $templateParametersPath "computeNetwork" "name" "$computeNetwork" .name
  Set-OverrideParameter $templateParametersPath "computeNetwork" "resourceGroupName" "$computeNetwork" .resourceGroupName
  Set-OverrideParameter $templateParametersPath "computeNetwork" "regionName" "$computeNetwork" .regionName

  Set-OverrideParameter $templateParametersPath "storageNetwork" "name" "$storageNetwork" .name
  Set-OverrideParameter $templateParametersPath "storageNetwork" "resourceGroupName" "$storageNetwork" .resourceGroupName
  Set-OverrideParameter $templateParametersPath "storageNetwork" "regionName" "$storageNetwork" .regionName

  keyName="networkConnectionKey"
  Set-OverrideParameter $templateParametersPath $keyName "keyVault.id" $keyVaultId
  Set-OverrideParameter $templateParametersPath $keyName "secretName" $keyName

  resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Network")
  groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath)

  New-TraceMessage "$moduleName" true
fi
