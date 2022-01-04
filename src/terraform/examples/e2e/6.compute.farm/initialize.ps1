$mountFile = "C:\Windows\Temp\mount.bat"
New-Item -Path $mountFile -ItemType File
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }
Add-Content -Path $mountFile -Value "net stop Deadline10LauncherService"
Add-Content -Path $mountFile -Value "net start Deadline10LauncherService"

$taskName = "AAA Storage Mounts"
$taskAction = New-ScheduledTaskAction -Execute $mountFile
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System
Start-Process -FilePath $mountFile -Wait

$nextMinute = (Get-Date).Minute + 1
$terminater = "C:\Windows\Temp\terminate.ps1"
for ($i = 0; $i -lt 12; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * 5)
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "-ExecutionPolicy Unrestricted -File $terminater"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System
}
