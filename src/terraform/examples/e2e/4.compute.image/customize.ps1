param (
  [string] $subnetName,
  [string] $machineSize
)

Set-Location -Path "C:\Users\Default\Downloads"

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3")) {
  $fileName = "nvidia-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
}

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v4")) {
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

$schedulerVersion = "10.1.18.5"
$schedulerLicense = "LicenseFree"

$fileName = "Deadline-$schedulerVersion-windows-installers.zip"
$downloadUrl = "$storageContainerUrl/Deadline/$fileName$storageContainerSas"
Invoke-WebRequest $downloadUrl -OutFile $fileName
Expand-Archive -Path $fileName

Set-Location -Path "Deadline*"
if ($machineSize.StartsWith("Standard_L")) {
  $fileName = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
  Start-Process -FilePath $fileName -ArgumentList "--mode unattended --licensemode $schedulerLicense --dbLicenseAcceptance accept --installmongodb true" -Wait
} else {
  $fileName = "blender-2.93.5-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "/quiet /norestart" -Wait
}

$fileName = "DeadlineClient-$schedulerVersion-windows-installer.exe"
Start-Process -FilePath $fileName -ArgumentList "--mode unattended --licensemode $schedulerLicense" -Wait

if ($subnetName -eq "Workstation") {
  $fileName = "pcoip-agent-graphics_21.07.4.exe"
  Start-Process -FilePath $fileName -ArgumentList "/S /NoPostReboot" -Wait
}
