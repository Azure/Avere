param (
    [string] $gpuDriversUrl = "https://bit1.blob.core.windows.net/bin/Graphics/Windows",
    [string] $gpuDriverNVIDIA = "461.33_grid_win10_server2016_server2019_64bit_azure_swl.exe",
    [string] $gpuDriverAMD = "AMD-Azure-NVv4-Driver-20Q4.exe"
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

$processorInfo = Get-ComputerInfo | Select-Object -ExpandProperty "CsProcessors"
if ($processorInfo.Manufacturer.Contains("AMD")) {
    $fileName = $gpuDriverAMD
} else {
    $fileName = $gpuDriverNVIDIA
}
Invoke-WebRequest -OutFile $fileName -Uri "$gpuDriversUrl/$fileName?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
