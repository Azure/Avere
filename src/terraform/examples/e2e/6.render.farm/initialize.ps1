$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt 12; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * 5)
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $binDirectory\onTerminate.ps1"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force
}

$mountFile = "$binDirectory\mounts.bat"
New-Item -ItemType File -Path $mountFile
%{ for fsMount in fileSystemMountsStorage }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }
%{ for fsMount in fileSystemMountsStorageCache }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }
%{ if renderManager == "RoyalRender" }
  %{ for fsMount in fileSystemMountsRoyalRender }
    Add-Content -Path $mountFile -Value "${fsMount}"
  %{ endfor }
%{ endif }
%{ if renderManager == "Deadline" }
  %{ for fsMount in fileSystemMountsDeadline }
    Add-Content -Path $mountFile -Value "${fsMount}"
  %{ endfor }
%{ endif }

$taskName = "AAA File System Mounts"
$taskAction = New-ScheduledTaskAction -Execute $mountFile
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force

Start-Process -FilePath $mountFile -Wait -RedirectStandardOutput "fs-mounts.output.txt" -RedirectStandardError "fs-mounts.error.txt"
%{ for fsPermission in fileSystemPermissions }
  ${fsPermission}
%{ endfor }
