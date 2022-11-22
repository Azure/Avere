$ErrorActionPreference = "Stop"

$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt 12; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * 5)
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File C:\Windows\Temp\terminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force
}

%{ if length(fileSystemMounts) > 0 }
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
  %{ for fsPermission in fileSystemPermissions }
    ${fsPermission}
  %{ endfor }
%{ endif }