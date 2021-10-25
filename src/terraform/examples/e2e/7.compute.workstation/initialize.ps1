$fsMountPath = "$env:AllUsersProfile\\Microsoft\\Windows\\Start Menu\\Programs\\StartUp\\FSMount.bat"
New-Item -Path $fsMountPath -ItemType File
%{ for fsMount in fileSystemMounts ~}
  Add-Content -Path $fsMountPath -Value "${fsMount}"
%{ endfor ~}

if ($teradiciLicenseKey -ne "") {
  Set-Location -Path "C:\\Program Files\\Teradici\\PCoIP Agent"
  & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
  Restart-Service -Name "PCoIPAgent"
}
