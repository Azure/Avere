function New-TraceMessage {
  moduleName=$1
  moduleEnd=$2
  traceMessage=$(date +%H:%M:%S)
  if [ $moduleEnd == true ]; then
    traceMessage+="   END"
  else
    traceMessage+=" START"
  fi
  echo "$traceMessage $moduleName"
}

function Set-ResourceGroup {
  regionName=$1
  resourceGroupNamePrefix=$2
  resourceGroupNameSuffix=$3
  resourceGroupName="$resourceGroupNamePrefix$resourceGroupNameSuffix"
  az group create --name $resourceGroupName --location $regionName --output none
  echo $resourceGroupName
}

function Set-TemplateParameter {
  templateParametersPath=$1
  objectName=$2
  propertyName=$3
  propertyData=$4
  propertyFilter=$5
  if [ "$propertyFilter" != "" ]; then
    propertyValue=$(Get-PropertyValue $propertyData $propertyFilter)
  else
    propertyValue=$propertyData
  fi
  if [[ $propertyValue != \"*\" && $propertyValue != \{*\} && $propertyValue != \[*\] ]]; then
    propertyValue=\"$propertyValue\"
  fi
  valueReference=$([[ $propertyName == "keyVault.id" || $propertyName == "secretName" ]] && echo "reference" || echo "value")
  if [ "$propertyName" == "" ]; then
    templateParameters=$(jq .parameters.$objectName.$valueReference=$propertyValue $templateParametersPath)
  elif [[ $propertyName == *.* ]]; then
    IFS="."
    read -ra propertyNames <<< "$propertyName"
    unset IFS
    templateParameters=$(jq .parameters.$objectName.$valueReference.${propertyNames[0]}.${propertyNames[1]}=$propertyValue $templateParametersPath)
  else
    templateParameters=$(jq .parameters.$objectName.$valueReference.$propertyName=$propertyValue $templateParametersPath)
  fi
  echo "$templateParameters" > $templateParametersPath
}

function Set-StorageScripts {
  rootDirectory=$1
  moduleDirectory=$2
  storageAccountName=$3
  storageContainerName=$4
  functionName="(**) Set Storage Scripts"
  systemType="Linux"
  scriptFilePattern="[0-9]*.sh"
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" false
  sourceDirectory="$rootDirectory/$moduleDirectory/$systemType"
  destinationDirectory="$storageContainerName/$moduleDirectory/$systemType"
  az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern "$scriptFilePattern" --auth-mode login --output none --no-progress
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" true
  systemType="Windows"
  scriptFilePattern="[0-9]*.ps1"
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" false
  sourceDirectory="$rootDirectory/$moduleDirectory/$systemType"
  destinationDirectory="$storageContainerName/$moduleDirectory/$systemType"
  az storage blob upload-batch --account-name $storageAccountName --destination $destinationDirectory --source $sourceDirectory --pattern "$scriptFilePattern" --auth-mode login --output none --no-progress
  New-TraceMessage "$functionName ($moduleDirectory, $systemType)" true
}

function Get-PropertyValue {
  objectData=$1
  propertyFilter=$2
  enableRawOutput=$3
  jqOptions=$([ "$enableRawOutput" == true ] && echo "-rc" || echo "-c")
  echo $(echo "$objectData" | jq $jqOptions $propertyFilter)
}

function Get-ImageVersion {
  imageTemplate=$1
  imageGallery=$2
  imageGalleryName=$(Get-PropertyValue $imageGallery .name true)
  imageGalleryResourceGroupName=$(Get-PropertyValue $imageGallery .resourceGroupName true)
  imageDefinitionName=$(Get-PropertyValue $imageTemplate .imageDefinitionName true)
  imageVersions=$(az sig image-version list --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName | jq -c .)
  for imageVersion in $(echo $imageVersions | jq -c '.[]'); do
    imageTemplateName1=$(Get-PropertyValue $imageVersion .tags.imageTemplateName)
    imageTemplateName2=$(Get-PropertyValue $imageTemplate .name)
    if [ $imageTemplateName1 == $imageTemplateName2 ]; then
      echo $imageVersion
    fi
  done
}

function Build-ImageTemplates {
  moduleName=$1
  computeRegionName=$2
  imageTemplates=$3
  imageGallery=$4
  New-TraceMessage "$moduleName" false
  for imageTemplate in $(echo "$imageTemplates" | jq -c '.[]'); do
    imageTemplateDeploy=$(Get-PropertyValue $imageTemplate .deploy true)
    if [ $imageTemplateDeploy == true ]; then
      imageVersion=$(Get-ImageVersion $imageTemplate $imageGallery)
      if [[ -v imageVersion ]]; then
        imageTemplateName=$(Get-PropertyValue $imageTemplate .name true)
        imageGalleryResourceGroupName=$(Get-PropertyValue $imageGallery .resourceGroupName true)
        New-TraceMessage "$moduleName [$imageTemplateName]" false
        az image builder run --resource-group $imageGalleryResourceGroupName --name $imageTemplateName --output none
        New-TraceMessage "$moduleName [$imageTemplateName]" true
      fi
    fi
  done
  New-TraceMessage "$moduleName" true
}
