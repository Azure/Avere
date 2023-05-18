$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

if ("${fileSystemMount.enable}" -eq $true) {
  SetMount "${fileSystemMount.storageRead}" "${fileSystemMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fileSystemMount.storageWrite}" "${fileSystemMount.storageWriteCache}" "${storageCache.enableWrite}"
  if ("${renderManager}" -like "*Deadline*") {
    AddMount "${fileSystemMount.schedulerDeadline}"
  }
  $installType = "file-system-mount"
  Start-Process -FilePath $fileSystemMountPath -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
}

EnableRenderClient "${renderManager}" "${servicePassword}"

if ("${terminateNotification.enable}" -eq $true) {
  $taskName = "AAA Terminate Event Handler"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\AzureData\terminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $(Get-Date) -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
}
