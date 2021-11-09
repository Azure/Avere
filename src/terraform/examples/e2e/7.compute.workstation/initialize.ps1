$fsMountPath = "$env:AllUsersProfile\Microsoft\Windows\Start Menu\Programs\StartUp\FSMount.bat"
New-Item -Path $fsMountPath -ItemType File
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $fsMountPath -Value "${fsMount}"
%{ endfor }
Start-Process -FilePath $fsMountPath -Wait

Set-Location -Path "C:\Program Files\Thinkbox\Deadline10\bin"
./deadlinecommand -ChangeRepository "Direct" "S:\" '""' '""'

%{ if teradiciLicenseKey != "" }
  Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent"
  & .\pcoip-register-host.ps1 -RegistrationCode ${teradiciLicenseKey}
  Restart-Service -Name "PCoIPAgent"
%{ endif }
