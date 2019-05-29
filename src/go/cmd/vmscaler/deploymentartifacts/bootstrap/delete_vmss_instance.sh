#!/bin/bash

# uses the IMDS to get the VMSS name and ID to post a message queue
#
# the curl technique guidance from:
#   https://social.msdn.microsoft.com/Forums/lync/en-US/8ea29f47-6256-4873-8370-9fe92089a349/how-to-access-rest-azure-blob-using-curl?forum=windowsazuredata
#   https://gist.github.com/rtyler/30e51dc72bed23718388c43f9c11da76
#   https://stackoverflow.com/questions/42361336/how-to-make-a-rest-call-to-an-azure-queue
#   https://docs.microsoft.com/en-us/rest/api/storageservices/put-message

set -x

# provided by system
STORAGE_ACCOUNT="STORAGEACCOUNTREPLACE"
AZURE_STORAGE_ACCOUNT_KEY="STORAGEKEYREPLACE"

# provided by IMDS
AZURE_SUBSCRIPTION_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2018-10-01&format=text")
RESOURCE_GROUP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2018-10-01&format=text")
CONTAINER_NAME="vmscaler-${AZURE_SUBSCRIPTION_ID}-${RESOURCE_GROUP}"
VMSS_NAME=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmScaleSetName?api-version=2018-10-01&format=text")
VMSS_INSTANCE_ID=$(curl -s -H Metadata:true -s "http://169.254.169.254/metadata/instance/compute/name?api-version=2018-10-01&format=text" | awk -F'_' '{print $2}')

if [ "${#VMSS_NAME}" -eq 0 ];
then
    echo "ERROR: this is not a VMSS Instance"
    exit 1
fi

# storage variables
QUEUE_STORE_URL="queue.core.windows.net"
AUTHORIZATION="SharedKey"

REQUEST_METHOD="POST"
REQUEST_DATE=$(TZ=GMT LC_ALL=en_US.utf8 date "+%a, %d %h %Y %H:%M:%S %Z")
STORAGE_SERVICE_VERSION="2018-03-28"

# HTTP Request headers
X_MS_DATE_H="x-ms-date:$REQUEST_DATE"
X_MS_VERSION_H="x-ms-version:$STORAGE_SERVICE_VERSION"

# Build the SIGNATURE string
CANONICALIZED_HEADERS="${X_MS_DATE_H}\n${X_MS_VERSION_H}"
RESOURCE_ID="/${CONTAINER_NAME}/messages"
CANONICALIZED_RESOURCE="/${STORAGE_ACCOUNT}${RESOURCE_ID}"

QUEUE_MESSAGE="<QueueMessage><MessageText>${VMSS_NAME},${VMSS_INSTANCE_ID}</MessageText></QueueMessage>"
MESSAGE_LENGTH=$(echo -n "${QUEUE_MESSAGE}" | wc --bytes)
CONTENT_TYPE="application/x-www-form-urlencoded"

STRING_TO_SIGN="${REQUEST_METHOD}\n\n\n${MESSAGE_LENGTH}\n\n${CONTENT_TYPE}\n\n\n\n\n\n\n${CANONICALIZED_HEADERS}\n${CANONICALIZED_RESOURCE}"

# Decode the Base64 encoded access key, convert to Hex.
DECODED_HEX_KEY="$(echo -n $AZURE_STORAGE_ACCOUNT_KEY | base64 -d -w0 | xxd -p -c256)"

# Create the HMAC SIGNATURE for the Authorization header
SIGNATURE=$(printf "$STRING_TO_SIGN" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$DECODED_HEX_KEY" -binary |  base64 -w0)
AUTHORIZATION_HEADER="Authorization: $AUTHORIZATION $STORAGE_ACCOUNT:$SIGNATURE"

curl --verbose --retry 18 --retry-delay 10 \
    -X $REQUEST_METHOD \
    -H "$X_MS_DATE_H" \
    -H "$X_MS_VERSION_H" \
    -H "$AUTHORIZATION_HEADER" \
    -d $QUEUE_MESSAGE \
    https://${STORAGE_ACCOUNT}.${QUEUE_STORE_URL}${RESOURCE_ID}

echo "curl result: $?"