$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$databaseFile = "C:\Windows\Temp\database.ps1"
New-Item -ItemType File -Path $databaseFile
Add-Content -Path $databaseFile -Value '$serviceName = "Deadline10DatabaseService"'
Add-Content -Path $databaseFile -Value '$serviceStatus = (Get-Service -Name $serviceName).Status'
Add-Content -Path $databaseFile -Value 'if ($serviceStatus -ne "Running") { Start-Service -Name $serviceName }'

$taskName = "AAA Scheduler Database"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Minutes 5
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $databaseFile"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force

$customDataInputFile = "C:\AzureData\CustomData.bin"
$customDataOutputFile = "C:\AzureData\Scale.ps1"
$fileStream = New-Object System.IO.FileStream($customDataInputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$streamReader = New-Object System.IO.StreamReader($fileStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $customDataOutputFile

$taskName = "AAA Render Farm Scaler"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Seconds ${autoScale.detectionIntervalSeconds}
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $customDataOutputFile -resourceGroupName ${autoScale.resourceGroupName} -scaleSetName ${autoScale.scaleSetName} -jobWaitThresholdSeconds ${autoScale.jobWaitThresholdSeconds} -workerIdleDeleteSeconds ${autoScale.workerIdleDeleteSeconds}"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force

while ($null -eq (Get-ScheduledTask $taskName -ErrorAction SilentlyContinue)) {
  Start-Sleep -Seconds 1
}
if ("${autoScale.enable}" -ne "true") {
  Disable-ScheduledTask -TaskName $taskName
}

$mountFile = "C:\Windows\Temp\mounts.bat"
New-Item -ItemType File -Path $mountFile
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }

$taskName = "AAA Storage Mounts"
$taskAction = New-ScheduledTaskAction -Execute $mountFile
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force

Start-Process -FilePath $mountFile -Wait -RedirectStandardOutput "$mountFile.output.txt" -RedirectStandardError "$mountFile.error.txt"