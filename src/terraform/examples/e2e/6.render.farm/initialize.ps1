$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

if ("${fsMount.enable}" -eq "true") {
  SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
  if ("${renderManager}" -like "*Deadline*") {
    AddMount "${fsMount.schedulerDeadline}"
  }
  $installType = "fs-mount"
  Start-Process -FilePath $fsMountPath -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
}

EnableRenderClient "${renderManager}" "${servicePassword}"

$taskCount = 60 / ${terminateNotificationDetectionIntervalSeconds}
$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt $taskCount; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * ${terminateNotificationDetectionIntervalSeconds})
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\AzureData\terminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
}
