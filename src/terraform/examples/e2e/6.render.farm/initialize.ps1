$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

$functionsData = "C:\AzureData\CustomData.bin"
$functionsCode = "C:\AzureData\functions.ps1"
$fileStream = New-Object System.IO.FileStream($functionsData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$streamReader = New-Object System.IO.StreamReader($fileStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $functionsCode -Force
. $functionsCode

SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
if ("${renderManager}" -like "*Deadline*") {
  AddMount "${fsMount.schedulerDeadline}"
}
RegisterMounts

EnableRenderClient "${renderManager}" "${servicePassword}"

$taskCount = 60 / ${terminateNotificationDetectionIntervalSeconds}
$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt $taskCount; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * ${terminateNotificationDetectionIntervalSeconds})
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\Windows\terminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
}
