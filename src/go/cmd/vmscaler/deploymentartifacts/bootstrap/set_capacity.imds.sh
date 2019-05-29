#!/bin/bash

display_usage() {
    echo -e "\nUsage: $0 NEW_NODE_COUNT\n"
    echo -e "sets capacity using values from IMDS.  Access to management.azure.com must exist and IMDS must have write access to the resource group."
}

if [ $# -lt 1 ] ; then
    display_usage
    exit 1
fi

NEW_NODE_COUNT=$1

if [ "$NEW_NODE_COUNT" -eq "$NEW_NODE_COUNT" ] ;
then
   echo "$NEW_NODE_COUNT is a valid integer"
else
   echo "ERROR: NEW_NODE_COUNT must be a valid integer."
   exit 1
fi

set -x
set -e

# https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-use-vm-token#get-a-token-using-http

# get the bearer token
BEARER_TOKEN=$(curl -s -H "Metadata: true" 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' | grep -Po 'access_token":"\K[^"]*')

# get sub id and resource groups
AZURE_SUBSCRIPTION_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2018-10-01&format=text")
RESOURCE_GROUP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2018-10-01&format=text")

# get the existing resource group metadata
RESOURCE_GROUP_PAYLOAD=$(curl -s -H "Authorization: Bearer ${BEARER_TOKEN}" -H "Content-Type: application/json" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP}?api-version=2018-05-01")

NEW_PAYLOAD=$(echo $RESOURCE_GROUP_PAYLOAD | sed -r "s/\"TOTAL_NODES\":\"[0-9]*\"/\"TOTAL_NODES\":\"${NEW_NODE_COUNT}\"/g" | sed -r "s/\"properties\":\{[^\}]*\}/\"properties\":\{\}/g")

curl --verbose --retry 18 --retry-delay 10 \
    -X PATCH \
    -H "Authorization: Bearer ${BEARER_TOKEN}" \
    -H "Content-Type: application/json" \
    -d $NEW_PAYLOAD \
    "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP}?api-version=2018-05-01"
    
set -x