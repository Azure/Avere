param (
    [string] $teradiciLicenseKey
)

Set-Location -Path '/Users/Public/Downloads'

$installProcess = Start-Process -FilePath 'pcoip-agent-graphics.exe' -ArgumentList '/S /NoPostReboot' -Wait -PassThru

if ($teradiciLicenseKey -ne '' -and ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 1641)) {
    Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
    & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
    & .\pcoip-validate-license.ps1
}

Restart-Service -Name 'PCoIPAgent'
