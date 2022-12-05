$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

%{ if teradiciLicenseKey != "" }
  $agentFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$agentFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "pcoip-agent.output.txt" -RedirectStandardError "pcoip-agent.error.txt"
%{ endif }

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
