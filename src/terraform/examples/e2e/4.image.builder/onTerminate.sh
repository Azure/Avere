#!/bin/bash -ex

cycleCloudEnable=false

function RemoveWorker {
  renderManager="$1"
  if [ $renderManager == "*Qube*" ]; then
    qbadmin worker --remove $(hostname)
  fi
  if [ $renderManager == "*Deadline*" ]; then
    deadlineworker -shutdown
    deadlinecommand -DeleteSlave $(hostname)
  fi
}

if [ $cycleCloudEnable == true ]; then
  RemoveWorker $renderManager
else
  scheduledEvents=$(curl -H Metadata:true "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01" | jq -c .Events)
  for scheduledEvent in $(echo $scheduledEvents | jq -r '.[] | @base64'); do
    _jq() {
      echo $scheduledEvent | base64 -d | jq -r $1
    }
    eventType=$(_jq .EventType)
    if [[ $eventType == "Preempt" || $eventType == "Terminate" ]]; then
      eventScope=$(_jq .Resources)
      instanceName=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-05-01&format=text")
      if [[ $eventScope == *$instanceName* ]]; then
        RemoveWorker $renderManager
      fi
    fi
  done
fi
