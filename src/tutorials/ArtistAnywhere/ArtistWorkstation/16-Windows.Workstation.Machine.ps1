param (
    [string] $renderManagerHost,
    [string] $teradiciLicenseKey
)

[System.Environment]::SetEnvironmentVariable("CUEBOT_HOSTS", $renderManagerHost, [System.EnvironmentVariableTarget]::Machine)

if ($teradiciLicenseKey -ne '') {
    $fileName = "Teradici-Graphics-Agent-20102.exe"
    Set-Location -Path "C:\Users\Public\Downloads\Teradici"
    Start-Process -FilePath $fileName -ArgumentList '/S /NoPostReboot' -Wait
    Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent\"
    & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
    & .\pcoip-validate-license.ps1
    Restart-Service -Name "PCoIPAgent"
}
