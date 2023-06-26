$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

SetServiceAccount ${serviceAccountName} ${serviceAccountPassword}

$fileSystemMounts = ConvertFrom-Json -InputObject '${jsonencode(fileSystemMounts)}'
foreach ($fileSystemMount in $fileSystemMounts) {
  if ($fileSystemMount.enable -eq $true) {
    SetFileSystemMount $fileSystemMount.mount
  }
}
RegisterFileSystemMountPath

EnableSchedulerClient "${renderManager}" ${serviceAccountName} ${serviceAccountPassword}

if ("${terminateNotification.enable}" -eq $true) {
  $taskName = "AAA Terminate Event Handler"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\AzureData\terminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $(Get-Date) -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
}
