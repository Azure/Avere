param (
  [string] $sizeSku,
  [string] $subnetName
)

Set-Location -Path "C:\User\Default\Downloads"

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if ($sizeSku.Contains("Standard_NV") && $sizeSku.Contains("_v3")) {
  $fileName = "nvidia-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
}

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if ($sizeSku.Contains("Standard_NV") && $sizeSku.Contains("_v4")) {
  $fileName = "amd-gpu.exe"
  $downloadUrl = "https://download.microsoft.com/download/3/4/8/3481cf8d-1706-49b0-aa09-08c9468305ab/AMD-Azure-NVv4-Windows-Driver-21Q2.exe"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/S" -Wait
}

DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
$registryKeyPath = "HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default"
New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0

$registryKeyName = "OOBE"
$registryKeyPath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows"
New-Item –Path $registryKeyPath –Name $registryKeyName -Force
New-ItemProperty -Path $registryKeyPath\$registryKeyName -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force

$storageContainerUrl = "https://az0.blob.core.windows.net/bin"
$storageContainerSas = "?sp=r&sr=c&sig=Ysr0iLGUhilzRYPHuY066aZ69iT46uTx87pP2V%2BdMEY%3D&sv=2020-08-04&se=2222-12-31T00%3A00%3A00Z"

fileName="Deadline-10.1.18.5-windows-installers.zip"
curl -L -o $fileName "$storageContainerUrl/Deadline/$fileName$storageContainerSas"
unzip $fileName

fileName="Autodesk_Maya_2022_ML_Windows_64bit_di_ML_setup_webinstall.exe"
curl -L -o $fileName "$storageContainerUrl/Deadline/$fileName$storageContainerSas"

if ($sizeSku -eq "Workstation") {
  $fileName = "pcoip-agent-graphics_21.07.4.exe"
  Start-Process -FilePath $fileName -ArgumentList "/S /NoPostReboot" -Wait
}
