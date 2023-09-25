#!/bin/bash -x

metadataUrl="http://169.254.169.254/metadata"
eventsUrl="$metadataUrl/scheduledevents?api-version=2020-07-01"
vmNameUrl="$metadataUrl/instance/compute/name?api-version=2021-12-13&format=text"

function GetEventValue {
  echo $scheduledEvent | base64 -d | jq -r $1
}

scheduledEvents=$(curl --header Metadata:true $eventsUrl | jq -c .Events)
for scheduledEvent in $(echo $scheduledEvents | jq -r '.[] | @base64'); do
  eventType=$(GetEventValue .EventType)
  if [[ $eventType == Preempt || $eventType == Terminate ]]; then
    eventScope=$(GetEventValue .Resources[0])
    instanceName=$(curl --header Metadata:true $vmNameUrl)
    if [ $eventScope == $instanceName ]; then
      deadlineworker -shutdown
      deadlinecommand -DeleteSlave $(hostname)
      eventId=$(GetEventValue .EventId)
      requestData="{\"StartRequests\":[{\"EventId\":\"$eventId\"}]}"
      curl --silent --request POST --header Metadata:true --header Content-Type:application/json --data $requestData $eventsUrl
    fi
  fi
done
