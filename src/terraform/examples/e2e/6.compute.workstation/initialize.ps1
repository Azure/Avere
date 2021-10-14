param (
  [string] $teradiciLicenseKey
)

if ($teradiciLicenseKey -ne '') {
  Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent\"
  & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
  Restart-Service -Name "PCoIPAgent"
}
