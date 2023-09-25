$metadataUrl = "http://169.254.169.254/metadata"
$eventsUrl = "$metadataUrl/scheduledevents?api-version=2020-07-01"
$vmNameUrl = "$metadataUrl/instance/compute/name?api-version=2021-12-13&format=text"

$scheduledEvents = (Invoke-RestMethod -Headers @{"Metadata"="true"} -Uri $eventsUrl).Events
foreach ($scheduledEvent in $scheduledEvents) {
  $eventType = $scheduledEvent.EventType
  if ($eventType -eq "Preempt" -or $eventType -eq "Terminate") {
    $eventScope = $scheduledEvent.Resources[0]
    $instanceName = Invoke-RestMethod -Headers @{"Metadata"="true"} -Uri $vmNameUrl
    if ($eventScope -eq $instanceName) {
      deadlineworker -shutdown
      deadlinecommand -DeleteSlave $(hostname)
      $eventId = $scheduledEvent.eventId
      $requestBody = "{\"StartRequests\":[{\"EventId\":\"$eventId\"}]}"
      $requestHeaders = @{
        "Content-Type" = "application/json"
        "Metadata"     = "true"
      }
      Invoke-WebRequest -Method "POST" -Headers $requestHeaders -Body $requestBody -Uri $eventsUrl
    }
  }
}
