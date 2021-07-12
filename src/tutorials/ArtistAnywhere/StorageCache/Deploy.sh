#!/bin/bash

computeRegionName=""    # List Azure region names via Azure CLI (az account list-locations --query [].name)
storageRegionName=""    # List Azure region names via Azure CLI (az account list-locations --query [].name)
resourceGroupPrefix=""  # Alphanumeric characters, periods, underscores, hyphens and parentheses are valid

computeNetworkName=""
storageNetworkName=""
networkResourceGroupName=""

managedIdentityName=""
managedIdentityResourceGroupName=""

enableHPCCache=false

modulePath=$(pwd)
rootDirectory="$modulePath/.."
moduleDirectory="$(basename $(pwd))"
source "$rootDirectory/Functions.sh"

function Set-MountUnitFile {
  outputDirectory=$1
  mount=$2
  mountType=$(Get-PropertyValue $mount .type)
  mountHost=$(Get-PropertyValue $mount .host)
  mountPath=$(Get-PropertyValue $mount .path)
  mountOptions=$(Get-PropertyValue $mount .options)
  outputFileName=$(echo ${mountPath:1} | sed 's|/|-|g')
  outputFilePath="$outputDirectory/$outputFileName.mount"
  echo "[Unit]" > $outputFilePath
  echo "After=network-online.target" >> $outputFilePath
  echo "" >> $outputFilePath
  echo "[Mount]" >> $outputFilePath
  echo "Type=$mountType" >> $outputFilePath
  echo "What=$mountHost" >> $outputFilePath
  echo "Where=$mountPath" >> $outputFilePath
  echo "Options=$mountOptions" >> $outputFilePath
  echo "" >> $outputFilePath
  echo "[Install]" >> $outputFilePath
  echo "WantedBy=multi-user.target" >> $outputFilePath
}

# (05) Storage
moduleName="(05) Storage"
New-TraceMessage "$moduleName" false

templateResourcesPath="$modulePath/05.Storage.json"
templateParametersPath="$modulePath/05.Storage.Parameters.json"

Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $storageNetworkName
Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

resourceGroupName=$(Set-ResourceGroup $storageRegionName $resourceGroupPrefix ".Storage")
groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

storageAccounts=$(Get-PropertyValue "$groupDeployment" .properties.outputs.storageAccounts.value true)
storageMounts=$(Get-PropertyValue "$groupDeployment" .properties.outputs.storageMounts.value true)
storageTargets=$(Get-PropertyValue "$groupDeployment" .properties.outputs.storageTargets.value true)

for storageMount in $(echo "$storageMounts" | jq -c '.[]'); do
  Set-MountUnitFile "$modulePath" $storageMount
done

New-TraceMessage "$moduleName" true

if [ $enableHPCCache == true ]; then
  # (06) HPC Cache
  moduleName="(06) HPC Cache"
  New-TraceMessage "$moduleName" false

  templateResourcesPath="$modulePath/06.HPCCache.json"
  templateParametersPath="$modulePath/06.HPCCache.Parameters.json"

  Set-TemplateParameter $templateParametersPath "storageTargets" "" $storageTargets
  Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
  Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

  resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Cache")
  groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

  hpcCache=$(Get-PropertyValue "$groupDeployment" .properties.outputs.hpcCache.value true)

  New-TraceMessage "$moduleName" true

  # (06) HPC Cache DNS
  moduleName="(06) HPC Cache DNS"
  New-TraceMessage "$moduleName" false

  templateResourcesPath="$modulePath/06.HPCCache.DNS.json"
  templateParametersPath="$modulePath/06.HPCCache.DNS.Parameters.json"

  Set-TemplateParameter $templateParametersPath "hpcCache" "" $hpcCache
  Set-TemplateParameter $templateParametersPath "virtualNetwork" "name" $computeNetworkName
  Set-TemplateParameter $templateParametersPath "virtualNetwork" "resourceGroupName" $networkResourceGroupName

  resourceGroupName=$(Set-ResourceGroup $computeRegionName $resourceGroupPrefix ".Cache")
  groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateResourcesPath --parameters $templateParametersPath | jq -c .)

  hpcCacheMounts=$(Get-PropertyValue "$groupDeployment" .properties.outputs.hpcCacheMounts.value true)

  for cacheMount in $(echo "$hpcCacheMounts" | jq -c '.[]'); do
    Set-MountUnitFile "$modulePath" $cacheMount
  done

  New-TraceMessage "$moduleName" true
fi

# (**) Mount Unit Files
moduleName="(**) Mount Unit Files"
New-TraceMessage "$moduleName" false

storageAccountName=$(Get-PropertyValue $storageAccounts .[0].name)
storageContainerName="script"
mountFilePattern="*.mount"

sourceDirectory="$rootDirectory/$moduleDirectory"
destinationDirectory="$storageContainerName/$moduleDirectory"
az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern "$mountFilePattern" --auth-mode login --output none --no-progress

New-TraceMessage "$moduleName" true
