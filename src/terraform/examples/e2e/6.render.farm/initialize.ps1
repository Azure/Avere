$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$functionsFile = "$binDirectory\functions.ps1"
$functionsCode = "${ filebase64("../0.global/functions.ps1") }"
$functionsBytes = [System.Convert]::FromBase64String($functionsCode)
[System.Text.Encoding]::UTF8.GetString($functionsBytes) | Out-File $functionsFile -Force
& $functionsFile

$taskCount = 60 / ${terminationNotificationDetectionIntervalSeconds}
$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt $taskCount; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * ${terminationNotificationDetectionIntervalSeconds})
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $binDirectory\onTerminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force
}

$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsQube) }"
$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
RegisterFileSystemMounts $fsMountsFile

%{ for fsPermission in fileSystemPermissions }
  ${fsPermission}
%{ endfor }
