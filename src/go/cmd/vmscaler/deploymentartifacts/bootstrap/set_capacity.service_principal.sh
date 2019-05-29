#!/bin/bash

display_usage() {
    echo -e "\nUsage: $0 NEW_NODE_COUNT\n"
    echo -e "sets capacity on the resource group using environment variables."
    echo -e "Access to management.azure.com and login.microsoftonline.com must"
    echo -e "exist, and the following environment variables must be set:\n"
    echo -e "AZURE_SUBSCRIPTION_ID - the customer subscription id"
    echo -e "AZURE_TENANT_ID - the tenant ID associated with the subscription"
    echo -e "AZURE_CLIENT_ID - the service principal client id"
    echo -e "AZURE_CLIENT_SECRET - the service principal secret"
    echo -e "RESOURCE_GROUP - the resource group that needs the node count tag updated\n"
}



if [ $# -lt 1 ] ; then
    display_usage
    exit 1
fi

if [ ! "$AZURE_SUBSCRIPTION_ID" ] ; then
    echo "ERROR: missing env var AZURE_SUBSCRIPTION_ID"
    display_usage
    exit 1
fi

if [ -z "$AZURE_TENANT_ID" ] ; then
    echo "ERROR: missing env var AZURE_TENANT_ID"
    display_usage
    exit 1
fi

if [ -z "$AZURE_CLIENT_ID" ] ; then
    echo "ERROR: missing env var AZURE_CLIENT_ID"
    display_usage
    exit 1
fi

if [ -z "$AZURE_CLIENT_SECRET" ] ; then
    echo "ERROR: missing env var AZURE_CLIENT_SECRET"
    display_usage
    exit 1
fi

if [ -z "$RESOURCE_GROUP" ] ; then
    echo "ERROR: missing env var RESOURCE_GROUP"
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
BEARER_TOKEN=$(curl --verbose -X POST -d "grant_type=client_credentials&client_id=${AZURE_CLIENT_ID}&client_secret=${AZURE_CLIENT_SECRET}&resource=https%3A%2F%2Fmanagement.azure.com%2F" https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/token | grep -Po 'access_token":"\K[^"]*')

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