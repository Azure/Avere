$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$functionsFile = "C:\Users\Public\Downloads\functions.ps1"
$functionsCode = "${ filebase64("../0.global/functions.ps1") }"
$functionsBytes = [System.Convert]::FromBase64String($functionsCode)
[System.Text.Encoding]::UTF8.GetString($functionsBytes) | Out-File $functionsFile -Force
. $functionsFile

$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsRoyalRender) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
RegisterFileSystemMounts $fsMountsFile

$taskCount = 60 / ${terminationNotificationDetectionIntervalSeconds}
$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt $taskCount; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * ${terminationNotificationDetectionIntervalSeconds})
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\Windows\onTerminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
}
