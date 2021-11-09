$storageAccountName = "az0"
$storageQueueName = "event"
$storageQueueSas = '"?sv=2019-02-02&st=2021-11-07T18%3A29%3A39Z&se=2222-12-31T00%3A00%3A00Z&sp=ra&sig=w3EGvvYB2W0gvoyi9okQVZGfldNxsWDVQ5VmME58o7c%3D"'

$scheduledEvents = (Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01").Events
if ($scheduledEvents.Length -gt 0) {
  az storage message put --account-name $storageAccountName --queue-name $storageQueueName --sas-token $storageQueueSas --content $scheduledEvents
}
