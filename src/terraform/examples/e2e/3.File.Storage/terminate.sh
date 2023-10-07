#!/bin/bash -x

rootHost=${wekaClusterName}000000

logDirectory=/mnt/log
if ! mountpoint -q $logDirectory; then
  mkdir -p $logDirectory
  mount $rootHost:${binDirectory}/log $logDirectory
fi

metadataUrl="http://169.254.169.254/metadata"
eventsUrl="$metadataUrl/scheduledevents?api-version=2020-07-01"
vmNameUrl="$metadataUrl/instance/compute/name?api-version=2021-12-13&format=text"

instanceName=$(curl --silent --header Metadata:true $vmNameUrl)
scheduledEvents=$(curl --silent --header Metadata:true $eventsUrl | jq -c .Events)

function GetEventValue {
  echo $scheduledEvent | base64 -d | jq -r $1
}

for scheduledEvent in $(echo $scheduledEvents | jq -r '.[] | @base64'); do
  eventType=$(GetEventValue .EventType)
  eventScope=$(GetEventValue .Resources[0])

  if [[ $eventType == Terminate && $eventScope == $instanceName ]]; then
    az login --identity
    dnsRecordQuery="aRecords[?ipv4Address=='$(hostname -i)']"
    dnsRecordAddress=$(az network private-dns record-set a show --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --name ${dnsRecordSetName} --query $dnsRecordQuery --output tsv)
    if [ -n "$dnsRecordAddress" ]; then
      az network private-dns record-set a remove-record --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --record-set-name ${dnsRecordSetName} --ipv4-address $dnsRecordAddress --keep-empty-record-set
    fi

    weka user login admin ${wekaAdminPassword}
    instanceName="$instanceName-$(date +%T)"

    drivesRemoved=false
    driveIds=$(weka cluster drive --filter hostname=$(hostname),status=ACTIVE --output uuid --no-header | tr \\n ' ')
    driveIds=$${driveIds::-1}
    if [ "$driveIds" != "" ]; then
      weka cluster drive deactivate --force $driveIds &> $logDirectory/$instanceName-weka-cluster-drive-deactivate.log

      read -a driveIds <<< "$driveIds"
      for (( i=0; i<$${#driveIds[@]}; i++ )); do
        driveId=$${driveIds[i]}
        while
          driveStatus=$(weka cluster drive --filter uuid=$driveId --output status --no-header)
          [ $driveStatus != INACTIVE ]
        do
          sleep 3
        done
        weka cluster drive remove --force $driveId &> $logDirectory/$instanceName-weka-cluster-drive-remove-$driveId.log
      done
      drivesRemoved=true
    fi

    containersRemoved=false
    containerIds=$(weka cluster container --filter ips=$(hostname -i),status=UP --output id --no-header | tr \\n ' ')
    containerIds=$${containerIds::-1}
    if [ "$containerIds" != "" ]; then
      weka cluster container deactivate $containerIds &> $logDirectory/$instanceName-weka-cluster-container-deactivate.log

      read -a containerIds <<< "$containerIds"
      for (( i=0; i<$${#containerIds[@]}; i++ )); do
        containerId=$${containerIds[i]}
        while
          containerStatus=$(weka cluster container --HOST $rootHost --filter id=$containerId --output status --no-header)
          [ $containerStatus != INACTIVE ]
        do
          sleep 3
        done
        weka cluster container remove $containerId --HOST $rootHost &> $logDirectory/$instanceName-weka-cluster-container-remove-$containerId.log
      done
      containersRemoved=true
    fi

    if [[ $drivesRemoved == true && $containersRemoved == true ]]; then
      eventId=$(GetEventValue .EventId)
      requestData="{\"StartRequests\":[{\"EventId\":\"$eventId\"}]}"
      curl --silent --request POST --header Metadata:true --header Content-Type:application/json --data $requestData $eventsUrl &> $logDirectory/$instanceName-event-$eventId.log
    fi
  fi
done
