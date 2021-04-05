param (
    [string] $renderManagerHost,
    [string] $teradiciLicenseKey
)

Set-Location -Path "C:\Users\Public\Downloads"

[System.Environment]::SetEnvironmentVariable("CUEBOT_HOSTS", $renderManagerHost, [System.EnvironmentVariableTarget]::Machine)

if ($teradiciLicenseKey -ne '') {
    $fileName = "pcoip-agent-graphics_21.03.0.exe"
    Start-Process -FilePath $fileName -ArgumentList "/S /NoPostReboot" -Wait
    Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent\"
    & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
    Restart-Service -Name "PCoIPAgent"
}
