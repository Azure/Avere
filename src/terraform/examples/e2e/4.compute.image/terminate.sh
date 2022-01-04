#!/bin/bash -ex

scheduledEvents=$(curl -H Metadata:true http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01 | jq -c .Events)
for scheduledEvent in $(echo $scheduledEvents | jq -r '.[] | @base64'); do
  _jq() {
    echo $scheduledEvent | base64 -d | jq -r $1
  }
  echo $(_jq)
  eventType=$(_jq .EventType)
  if [[ $eventType == "Preempt" || $eventType == "Terminate" ]]; then
    : # Add efficient (time-limited) clean up code here as needed
  fi
done
