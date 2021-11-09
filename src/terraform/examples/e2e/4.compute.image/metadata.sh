#!/bin/bash -ex

storageAccountName="az0"
storageQueueName="event"
storageQueueSas='"?sv=2019-02-02&st=2021-11-07T18%3A29%3A39Z&se=2222-12-31T00%3A00%3A00Z&sp=ra&sig=w3EGvvYB2W0gvoyi9okQVZGfldNxsWDVQ5VmME58o7c%3D"'

scheduledEvents=$(curl -H Metadata:true http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01 | jq -r .Events)
if [ ${#scheduledEvents[@]} -gt 0 ]; then
  az storage message put --account-name $storageAccountName --queue-name $storageQueueName --sas-token $storageQueueSas --content $scheduledEvents
fi
