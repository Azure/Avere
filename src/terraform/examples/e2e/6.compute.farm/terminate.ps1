$scheduledEvents = (Invoke-RestMethod -Headers @{"Metadata"="true"} -Method Get -Uri "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01").Events
foreach ($scheduledEvent in $scheduledEvents) {
  Write-Host $scheduledEvent
  $eventType = $scheduledEvent.EventType
  if ($eventType -eq "Preempt" -or $eventType -eq "Terminate") {
    # Add efficient (time-limited) clean up code here as needed
  }
}
