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

templateFile="$templateDirectory/Identity.json"
templateParameters="$templateDirectory/Identity.Parameters.json"

groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters)

userIdentityName=$(jq -r '.properties.outputs.userIdentity.value.name' <<< "$groupDeployment")
userIdentityResourceGroupName=$(jq -r '.properties.outputs.userIdentity.value.resourceGroupName' <<< "$groupDeployment")
userIdentityPrincipalId=$(jq -r '.properties.outputs.userIdentity.value.principalId' <<< "$groupDeployment")

# Images
resourceGroupNameSuffix=".Images"
resourceGroupName="$resourceGroupNamePrefix$resourceGroupNameSuffix"

resourceGroupExists=$(az group exists --resource-group $resourceGroupName)
if [ "$resourceGroupExists" == "true" ]; then
    imageTemplates=$(jq -c '.parameters.imageTemplates.value' "$templateDirectory/Images.Parameters.json")
    for imageTemplate in $(jq -c '.[] | {deploy,name}' <<< "$imageTemplates"); do
        imageTemplateDeploy=$(jq -r '.deploy' <<< "$imageTemplate")
        if [ "$imageTemplateDeploy" == "true" ]; then
            imageTemplateName=$(jq -r '.name' <<< "$imageTemplate")
            az image builder delete --resource-group $resourceGroupName --name $imageTemplateName
        fi
    done
else
    az group create --resource-group $resourceGroupName --location $deploymentRegionName
fi

roleAssignments=$(jq -c '.parameters.roleAssignments.value.images' "$templateDirectory/Images.Parameters.json")
for roleAssignment in $(jq -r '.[]' <<< "$roleAssignments"); do
    az role assignment create --resource-group $resourceGroupName --assignee $userIdentityPrincipalId --role $roleAssignment
done
roleAssignments=$(jq -c '.parameters.roleAssignments.value.network' "$templateDirectory/Images.Parameters.json")
for roleAssignment in $(jq -r '.[]' <<< "$roleAssignments"); do
    az role assignment create --resource-group $virtualNetworkResourceGroupName --assignee $userIdentityPrincipalId --role $roleAssignment
done

templateFile="$templateDirectory/Images.json"
templateParameters="$templateDirectory/Images.Parameters.json"

overrideParameters="{\"userIdentity\":{\"value\":{\"name\":\"$userIdentityName\",\"resourceGroupName\":\"$userIdentityResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"virtualNetwork\":{\"value\":{\"name\":\"$virtualNetworkName\",\"subnetName\":\"$virtualNetworkSubnetName\",\"resourceGroupName\":\"$virtualNetworkResourceGroupName\"}}}"

groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters)

imageGalleryName=$(jq -r '.properties.outputs.imageGallery.value.name' <<< "$groupDeployment")
imageGalleryResourceGroupName=$(jq -r '.properties.outputs.imageGallery.value.resourceGroupName' <<< "$groupDeployment")

imageTemplates=$(jq -r '.properties.outputs.imageTemplates.value' <<< "$groupDeployment")
for imageTemplate in $(jq -c '.[] | {deploy,name,imageDefinitionName,imageOutputVersion}' <<< "$imageTemplates"); do
    imageTemplateDeploy=$(jq -r '.deploy' <<< "$imageTemplate")
    if [ "$imageTemplateDeploy" == "true" ]; then
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

customExtension=$(jq -c '.parameters.customExtension.value' "$templateDirectory/Machines.Parameters.json")

extensionFilePath=$(jq -r '.linux.fileName' <<< "$customExtension")
extensionFileParameters=$(jq -r '.linux.fileParameters' <<< "$customExtension")
extensionCommandsLinux=$(cat $extensionFilePath | iconv -f UTF8 -t UTF16LE | base64 -w 0)
extensionParametersLinux=$extensionFileParameters

extensionFilePath=$(jq -r '.windows.fileName' <<< "$customExtension")
extensionFileParameters=$(jq -r '.windows.fileParameters' <<< "$customExtension")
extensionCommandsWindows=$(echo -n "& {$(cat $extensionFilePath)} $extensionFileParameters" | iconv -f UTF8 -t UTF16LE | base64 -w 0)
extensionParametersWindows=""

az group create --resource-group $resourceGroupName --location $deploymentRegionName

templateFile="$templateDirectory/Machines.json"
templateParameters="$templateDirectory/Machines.Parameters.json"

overrideParameters="{\"userIdentity\":{\"value\":{\"name\":\"$userIdentityName\",\"resourceGroupName\":\"$userIdentityResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"imageGallery\":{\"value\":{\"name\":\"$imageGalleryName\",\"resourceGroupName\":\"$imageGalleryResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"virtualNetwork\":{\"value\":{\"name\":\"$virtualNetworkName\",\"subnetName\":\"$virtualNetworkSubnetName\",\"resourceGroupName\":\"$virtualNetworkResourceGroupName\"}}"
overrideParameters="$overrideParameters,\"customExtension\":{\"value\":{\"linux\":{\"scriptCommands\":\"$extensionCommandsLinux\",\"scriptParameters\":\"$extensionParametersLinux\"},\"windows\":{\"scriptCommands\":\"$extensionCommandsWindows\",\"scriptParameters\":\"$extensionParametersWindows\"}}}}"

groupDeployment=$(az deployment group create --resource-group $resourceGroupName --template-file $templateFile --parameters $templateParameters --parameters $overrideParameters)
