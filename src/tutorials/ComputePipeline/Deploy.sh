#!/bin/bash

deploymentRegionName="WestUS2"
resourceGroupNamePrefix="ComputePipeline"

virtualNetworkName="MediaPipeline"
virtualNetworkSubnetName="Desktop"
virtualNetworkResourceGroupName="Azure.Media.Pipeline.WestUS2.Network"

templateDirectory=$(pwd)

# Identity
resourceGroupNameSuffix=".Identity"
resourceGroupName="$resourceGroupNamePrefix$resourceGroupNameSuffix"

az group create --resource-group $resourceGroupName --location $deploymentRegionName

templateFile="$templateDirectory/ComputePipeline.Identity.json"
templateParameters="$templateDirectory/ComputePipeline.Identity.Parameters.json"

groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters)

userIdentityName=$(jq -r '.properties.outputs.userIdentity.value.name' <<< "$groupDeployment")
userIdentityResourceGroupName=$(jq -r '.properties.outputs.userIdentity.value.resourceGroupName' <<< "$groupDeployment")
userIdentityPrincipalId=$(jq -r '.properties.outputs.userIdentity.value.principalId' <<< "$groupDeployment")

# Images
resourceGroupNameSuffix=".Images"
resourceGroupName="$resourceGroupNamePrefix$resourceGroupNameSuffix"

imageTemplates=$(jq -c '.parameters.imageTemplates.value' "$templateDirectory/ComputePipeline.Images.Parameters.json")

resourceGroupExists=$(az group exists --resource-group $resourceGroupName)
if [ "$resourceGroupExists" = "true" ]; then
    for imageTemplate in $(jq -c '.[] | {enabled,name}' <<< "$imageTemplates"); do
        imageTemplateEnabled=$(jq -r '.enabled' <<< "$imageTemplate")
        if [ "$imageTemplateEnabled" = "true" ]; then
            imageTemplateName=$(jq -r '.name' <<< "$imageTemplate")
            az image builder delete --resource-group $resourceGroupName --name $imageTemplateName
        fi
    done
    az role assignment delete --assignee $userIdentityPrincipalId --resource-group $resourceGroupName 
    az role assignment delete --assignee $userIdentityPrincipalId --resource-group $virtualNetworkResourceGroupName
else
    az group create --resource-group $resourceGroupName --location $deploymentRegionName
fi

templateFile="$templateDirectory/ComputePipeline.Images.json"
templateParameters="$templateDirectory/ComputePipeline.Images.Parameters.json"

overrideParameters="{\"userIdentity\":{\"value\":{\"name\":\"$userIdentityName\",\"resourceGroupName\":\"$userIdentityResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"virtualNetwork\":{\"value\":{\"name\":\"$virtualNetworkName\",\"subnetName\":\"$virtualNetworkSubnetName\",\"resourceGroupName\":\"$virtualNetworkResourceGroupName\"}}}"

groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters)

imageGalleryName=$(jq -r '.properties.outputs.imageGallery.value.name' <<< "$groupDeployment")
imageGalleryResourceGroupName=$(jq -r '.properties.outputs.imageGallery.value.resourceGroupName' <<< "$groupDeployment")

for imageTemplate in $(jq -c '.[] | {enabled,name,imageDefinitionName,imageOutputVersion}' <<< "$imageTemplates"); do
    imageTemplateEnabled=$(jq -r '.enabled' <<< "$imageTemplate")
    if [ "$imageTemplateEnabled" = "true" ]; then
        imageTemplateName=$(jq -r '.name' <<< "$imageTemplate")
        imageDefinitionName=$(jq -r '.imageDefinitionName' <<< "$imageTemplate")
        imageOutputVersion=$(jq -r '.imageOutputVersion' <<< "$imageTemplate")
        az sig image-version delete --resource-group $imageGalleryResourceGroupName --gallery-name $imageGalleryName --gallery-image-definition $imageDefinitionName --gallery-image-version $imageOutputVersion
        az image builder run --resource-group $resourceGroupName --name $imageTemplateName
    fi
done

# Machines
resourceGroupNameSuffix=".Machines"
resourceGroupName="$resourceGroupNamePrefix$resourceGroupNameSuffix"

templateParameters=$(jq -c '.parameters' "$templateDirectory/ComputePipeline.Machines.Parameters.json")

extensionFilePath=$(jq -r '.customExtension.value.linux.fileName' <<< "$templateParameters")
extensionFileParameters=$(jq -r '.customExtension.value.linux.fileParameters' <<< "$templateParameters")
extensionCommandsLinux=$(cat $extensionFilePath | gzip | base64)
extensionParametersLinux=$extensionFileParameters

extensionFilePath=$(jq -r '.customExtension.value.windows.fileName' <<< "$templateParameters")
extensionFileParameters=$(jq -r '.customExtension.value.windows.fileParameters' <<< "$templateParameters")
extensionCommandsWindows=$(cat $extensionFilePath)
extensionCommandsWindows="& {$extensionCommandsWindows} $extensionFileParameters"
extensionCommandsWindows=$(echo $extensionCommandsWindows | base64)
extensionParametersWindows=""

az group create --resource-group $resourceGroupName --location $deploymentRegionName

templateFile="$templateDirectory/ComputePipeline.Machines.json"
templateParameters="$templateDirectory/ComputePipeline.Machines.Parameters.json"

overrideParameters="{\"userIdentity\":{\"value\":{\"name\":\"$userIdentityName\",\"resourceGroupName\":\"$userIdentityResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"imageGallery\":{\"value\":{\"name\":\"$imageGalleryName\",\"resourceGroupName\":\"$imageGalleryResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"virtualNetwork\":{\"value\":{\"name\":\"$virtualNetworkName\",\"subnetName\":\"$virtualNetworkSubnetName\",\"resourceGroupName\":\"$virtualNetworkResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"customExtension\":{\"value\":{\"linux\":{\"scriptCommands\":\"$extensionCommandsLinux\",\"scriptParameters\":\"$extensionParametersLinux\"},\"windows\":{\"scriptCommands\":\"$extensionCommandsWindows\",\"scriptParameters\":\"$extensionParametersWindows\"}}}}"

groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters)
