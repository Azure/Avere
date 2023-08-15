$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

$serviceAccountName = "${serviceAccountName}"
if ("${activeDirectory.domainName}" -ne "") {
  JoinDomainComputer "${activeDirectory.domainName}" "${activeDirectory.serverName}" "${activeDirectory.adminUsername}" "${activeDirectory.adminPassword}"
  $serviceAccountName = "${activeDirectory.domainName}\$serviceAccountName"
} else {
  SetLocalUser $serviceAccountName ${serviceAccountPassword}
}

$fileSystemMounts = ConvertFrom-Json -InputObject '${jsonencode(fileSystemMounts)}'
foreach ($fileSystemMount in $fileSystemMounts) {
  if ($fileSystemMount.enable -eq $true) {
    SetFileSystemMount $fileSystemMount.mount
  }
}
RegisterFileSystemMountPath

EnableClientApp "${renderManager}" $serviceAccountName ${serviceAccountPassword}

if ("${terminateNotification.enable}" -eq $true) {
  $taskName = "AAA Terminate Event Handler"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\AzureData\terminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $(Get-Date) -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
}

if ("${activeDirectory.domainName}" -ne "") {
  Restart-Computer -Force
}
