$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$scheduledEvents = (Invoke-RestMethod -Headers @{"Metadata"="true"} -Method Get -Uri "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01").Events
foreach ($scheduledEvent in $scheduledEvents) {
  $eventType = $scheduledEvent.EventType
  if ($eventType -eq "Preempt" -or $eventType -eq "Terminate") {
    $eventScope = $scheduledEvent.Resources
    $instanceName = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method Get -Uri "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-05-01&format=text"
    if ($eventScope -like "*$instanceName*") {
      deadlineworker -shutdown
      deadlinecommand -DeleteSlave $(hostname)
    }
  }
}
