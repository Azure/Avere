DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
$registryKeyPath = "HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default"
New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0

$registryKeyName = "OOBE"
$registryKeyPath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows"
New-Item –Path $registryKeyPath –Name $registryKeyName -Force
New-ItemProperty -Path $registryKeyPath\$registryKeyName -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force

$vmSku = [System.Environment]::GetEnvironmentVariable("vmSku")

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if ($vmSku.Contains("Standard_NV") && $vmSku.Contains("_v3")) {
  $fileName = "nvidia-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
}

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if ($vmSku.Contains("Standard_NV") && $vmSku.Contains("_v4")) {
  $fileName = "amd-gpu.exe"
  $downloadUrl = "https://download.microsoft.com/download/3/4/8/3481cf8d-1706-49b0-aa09-08c9468305ab/AMD-Azure-NVv4-Windows-Driver-21Q2.exe"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/S" -Wait
}
