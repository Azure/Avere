#!/bin/bash -ex

scheduledEvents=$(curl -H Metadata:true "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01" | jq -c .Events)
for scheduledEvent in $(echo $scheduledEvents | jq -r '.[] | @base64'); do
  _jq() {
    echo $scheduledEvent | base64 -d | jq -r $1
  }
  eventType=$(_jq .EventType)

  if [[ $eventType == Preempt || $eventType == Terminate ]]; then
    eventScope=$(_jq .Resources[0])
    instanceName=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-05-01&format=text")

    if [ $eventScope == $instanceName ]; then
      if [[ $renderManager == *Deadline* ]]; then
        deadlineworker -shutdown
        deadlinecommand -DeleteSlave $(hostname)
      fi
      if [[ $renderManager == *RoyalRender* ]]; then
        :
      fi
    fi
  fi
done
