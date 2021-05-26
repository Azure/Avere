param (
    [string] $teradiciUrl = "https://bit1.blob.core.windows.net/bin/Teradici",
    [string] $teradiciAgent = "pcoip-agent-graphics_21.03.0.exe",
    [string] $teradiciLicenseKey = ""
)

Set-Location -Path "C:\Users\Public\Downloads"

$registryKeyName = "OOBE"
$registryKeyPath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows"
New-Item –Path $registryKeyPath –Name $registryKeyName -Force
New-ItemProperty -Path $registryKeyPath\$registryKeyName -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force

DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
$registryKeyPath = "HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default"
New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0

if ($teradiciLicenseKey -ne "") {
    Invoke-WebRequest -OutFile $teradiciAgent -Uri $teradiciUrl/$teradiciAgent
    Start-Process -FilePath $teradiciAgent -ArgumentList "/S /NoPostReboot" -Wait
    Set-Location -Path "C:\Program Files\Teradici\PCoIP Agent\"
    & .\pcoip-register-host.ps1 -RegistrationCode $teradiciLicenseKey
    Restart-Service -Name "PCoIPAgent"
}
