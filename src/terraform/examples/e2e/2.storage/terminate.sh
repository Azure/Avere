#!/bin/bash -ex

rootHost=${wekaClusterName}000000

logDirectory=/mnt/log
if ! mountpoint -q $logDirectory; then
  mkdir -p $logDirectory
  mount $rootHost:${binDirectoryPath}/log $logDirectory
fi

metadataUrl="http://169.254.169.254/metadata"
eventsUrl="$metadataUrl/scheduledevents?api-version=2020-07-01"
vmNameUrl="$metadataUrl/instance/compute/name?api-version=2021-12-13&format=text"

scheduledEvents=$(curl --silent --header Metadata:true $eventsUrl | jq -c .Events)
for scheduledEvent in $(echo $scheduledEvents | jq -r '.[] | @base64'); do
  _jq() {
    echo $scheduledEvent | base64 -d | jq -r $1
  }
  eventType=$(_jq .EventType)
  eventScope=$(_jq .Resources[0])
  instanceName=$(curl --silent --header Metadata:true $vmNameUrl)

  if [[ $eventType == "Terminate" && $eventScope == $instanceName ]]; then
    az login --identity
    dnsRecordQuery="aRecords[?ipv4Address=='$(hostname -i)']"
    dnsRecordAddress=$(az network private-dns record-set a show --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --name ${dnsRecordSetName} --query $dnsRecordQuery --output tsv)
    if [ -n $dnsRecordAddress ]; then
      az network private-dns record-set a remove-record --resource-group ${dnsResourceGroupName} --zone-name ${dnsZoneName} --record-set-name ${dnsRecordSetName} --ipv4-address $dnsRecordAddress --keep-empty-record-set
    fi

    weka user login admin ${wekaAdminPassword}

    driveIds=$(weka cluster drive --filter hostname=$(hostname) --output uuid --no-header | tr \\n ' ')
    driveIds=$${driveIds::-1}
    echo $driveIds &> $logDirectory/$instanceName-weka-cluster-drive-ids.log
    weka cluster drive deactivate --force $driveIds &> $logDirectory/$instanceName-weka-cluster-drive-deactivate.log

    drivesRemoved=true
    read -a driveIds <<< "$driveIds"
    for (( i=0; i<$${#driveIds[@]}; i++ )); do
      driveId=$${driveIds[i]}
      driveStatus=$(weka cluster drive --filter uuid=$driveId --output status --no-header)
      if [ $driveStatus == INACTIVE ]; then
        weka cluster drive remove --force $driveId &> $logDirectory/$instanceName-weka-cluster-drive-remove-$driveId.log
      elif [ -n $driveStatus ]; then
        drivesRemoved=false
      fi
    done

    containerIds=$(weka cluster container --filter ips=$(hostname -i) --output id --no-header | tr \\n ' ')
    containerIds=$${containerIds::-1}
    echo $containerIds &> $logDirectory/$instanceName-weka-cluster-container-ids.log
    weka cluster container deactivate $containerIds &> $logDirectory/$instanceName-weka-cluster-container-deactivate.log

    containersRemoved=true
    read -a containerIds <<< "$containerIds"
    for (( i=0; i<$${#containerIds[@]}; i++ )); do
      containerId=$${containerIds[i]}
      containerStatus=$(weka cluster container --HOST $rootHost --filter id=$containerId --output status --no-header)
      if [ $containerStatus == INACTIVE ]; then
        weka cluster container remove $containerId --HOST $rootHost &> $logDirectory/$instanceName-weka-cluster-container-remove-$containerId.log
      elif [ -n $containerStatus ]; then
        containersRemoved=false
      fi
    done

    if [[ $drivesRemoved == true && $containersRemoved == true ]]; then
      eventId=$(_jq .EventId)
      eventData="{\"StartRequests\":[{\"EventId\":\"$eventId\"}]}"
      curl --silent --request POST --header Metadata:true --header Content-Type:application/json --data $eventData $eventsUrl &> $logDirectory/$machineName-post-event-$eventId.log
    fi
  fi
done
