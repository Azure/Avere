param (
  [string[]] $fileSystemMounts,
  [string] $schedulerHostName,
  [string] $teradiciLicenseKey
)

$fsMountPath = "%AllUsersProfile%\Microsoft\Windows\Start Menu\Programs\StartUp\FSMount.bat"
New-Item -Path $fsMountPath -ItemType File
foreach ($fsMount in $fileSystemMounts) {
  Add-Content -Path $fsMountPath -Value $fsMount
}

if ($teradiciLicenseKey -ne "") {
  Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent\"
  & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
  Restart-Service -Name "PCoIPAgent"
}
