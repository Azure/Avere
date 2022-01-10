$mountFile = "C:\Windows\Temp\mounts.bat"
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

%{ if teradiciLicenseKey != "" }
  Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent"
  & .\pcoip-register-host.ps1 -RegistrationCode ${teradiciLicenseKey}
  Restart-Service -Name "PCoIPAgent"
%{ endif }
