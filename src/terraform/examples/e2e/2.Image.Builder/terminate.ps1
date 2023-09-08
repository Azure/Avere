param (
  [string] $renderManager
)

$ErrorActionPreference = "Stop"

$scheduledEvents = (Invoke-RestMethod -Headers @{"Metadata"="true"} -Uri "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01").Events
foreach ($scheduledEvent in $scheduledEvents) {
  $eventType = $scheduledEvent.EventType
  if ($eventType -eq "Preempt" -or $eventType -eq "Terminate") {
    $eventScope = $scheduledEvent.Resources[0]
    $instanceName = Invoke-RestMethod -Headers @{"Metadata"="true"} -Uri "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-12-13&format=text"
    if ($eventScope -eq $instanceName) {
      if ("$renderManager" -like "*Deadline*") {
        deadlineworker -shutdown
        deadlinecommand -DeleteSlave $(hostname)
      }
    }
  }
}
