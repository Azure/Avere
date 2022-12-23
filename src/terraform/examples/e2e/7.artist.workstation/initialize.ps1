$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

%{ if teradiciLicenseKey != "" }
  $agentFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$agentFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "pcoip-agent.output.txt" -RedirectStandardError "pcoip-agent.error.txt"
%{ endif }

$fsMountsFile = "$binDirectory\fs-mounts.bat"
New-Item -ItemType File -Path $fsMountsFile
%{ for fsMount in fileSystemMountsStorage }
  Add-Content -Path $fsMountsFile -Value "${fsMount}"
%{ endfor }
%{ for fsMount in fileSystemMountsStorageCache }
  Add-Content -Path $fsMountsFile -Value "${fsMount}"
%{ endfor }
%{ for fsMount in fileSystemMountsQube }
  Add-Content -Path $fsMountsFile -Value "${fsMount}"
%{ endfor }
%{ for fsMount in fileSystemMountsDeadline }
  Add-Content -Path $fsMountsFile -Value "${fsMount}"
%{ endfor }

$fsMountsFileSize = (Get-Item -Path $fsMountsFile).Length
if ($fsMountsFileSize -gt 0) {
  $taskName = "AAA File System Mounts"
  $taskAction = New-ScheduledTaskAction -Execute $fsMountsFile
  $taskTrigger = New-ScheduledTaskTrigger -AtStartup
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force
  Start-Process -FilePath $fsMountsFile -Wait -RedirectStandardOutput "fs-mounts.output.txt" -RedirectStandardError "fs-mounts.error.txt"
}
