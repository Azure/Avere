$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

Start-Process -FilePath sc.exe -ArgumentList "start Deadline10DatabaseService"

$scriptFile = "C:\AzureData\aaaScaler.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile

$taskName = "AAA Auto Scaler"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Seconds ${autoScale.detectionIntervalSeconds}
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $scriptFile -resourceGroupName ${autoScale.resourceGroupName} -scaleSetName ${autoScale.scaleSetName} -scaleSetMachineCountMax ${autoScale.scaleSetMachineCountMax} -jobWaitThresholdSeconds ${autoScale.jobWaitThresholdSeconds} -workerIdleDeleteSeconds ${autoScale.workerIdleDeleteSeconds}"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
if ("${autoScale.enable}" -ne $false) {
  $taskSettings = New-ScheduledTaskSettingsSet
} else {
  $taskSettings = New-ScheduledTaskSettingsSet -Disable
}
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User System -Force

if ("${activeDirectory.domainName}" -ne "") {
  $securePassword = ConvertTo-SecureString ${activeDirectory.adminPassword} -AsPlainText -Force
  Install-ADDSForest -DomainName "${activeDirectory.domainName}" -SafeModeAdministratorPassword $securePassword -InstallDns -Force
}
