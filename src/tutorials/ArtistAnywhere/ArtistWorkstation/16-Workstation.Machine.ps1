param (
    [string] $renderManagerHost,
    [string] $teradiciLicenseKey
)

Set-Location -Path 'C:\Users\Public\Downloads'

[System.Environment]::SetEnvironmentVariable('CUEBOT_HOSTS', $renderManagerHost, [System.EnvironmentVariableTarget]::Machine)

if ($teradiciLicenseKey -ne '') {
    Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
    & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
    & .\pcoip-validate-license.ps1
    Restart-Service -Name 'PCoIPAgent'
}
