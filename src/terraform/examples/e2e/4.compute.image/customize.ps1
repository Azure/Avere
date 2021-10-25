param (
  [string] $hostName,
  [string] $subnetName,
  [string] $machineSize,
  [string] $userPassword
)

Set-Location -Path "C:\\Users\\Default\\Downloads"

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if (($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3")) -or
    ($machineSize.StartsWith("Standard_NC") -and $machineSize.EndsWith("T4_v3"))) {
  $fileName = "nvidia-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
}

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v4")) {
  $fileName = "amd-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/S" -Wait
}

DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
$registryKeyPath = "HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default"
New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0

$storageContainerUrl = "https://az0.blob.core.windows.net/bin"
$storageContainerSas = "?sp=r&sr=c&sig=Ysr0iLGUhilzRYPHuY066aZ69iT46uTx87pP2V%2BdMEY%3D&sv=2020-08-04&se=2222-12-31T00%3A00%3A00Z"

$schedulerVersion = "10.1.19.4"
$schedulerLicense = "LicenseFree"
$schedulerHostName = "$hostName;127.0.0.1"
$schedulerShareName = "DeadlineRepository"
$schedulerRepositoryShare = "\\\\$hostName\\$schedulerShareName"
$schedulerCertificateFile = "Deadline10Client.pfx"
$schedulerCertificatePath = "$schedulerRepositoryShare\\certs\\$schedulerCertificateFile"
$schedulerCertificateSourcePath = "C:\\DeadlineDatabase10\\certs\\$schedulerCertificateFile"
$schedulerCertificateTargetPath = "C:\\DeadlineRepository10\\certs"

$fileName = "Deadline-$schedulerVersion-windows-installers.zip"
$downloadUrl = "$storageContainerUrl/Deadline/$fileName$storageContainerSas"
Invoke-WebRequest $downloadUrl -OutFile $fileName
Expand-Archive -Path $fileName

if ($subnetName -eq "Scheduler") {
  netsh advfirewall firewall add rule name="Allow MongoDB Port" dir=in action=allow protocol=TCP localport=27100
  Set-Location -Path "Deadline*"
  $fileName = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
  Start-Process -FilePath $fileName -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --dbhost $schedulerHostName --certgen_password $userPassword" -Wait
  Set-Location -Path ".."
  Copy-Item -Path $schedulerCertificateSourcePath -Destination $schedulerCertificateTargetPath
  Install-WindowsFeature -Name "FS-NFS-Service"
  New-NfsShare -Name $schedulerShareName -Path $schedulerCertificateTargetPath -Permission ReadWrite -AllowRootAccess $true
} else {
  $fileName = "blender-2.93.5-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "/quiet /norestart" -Wait
}

Set-Location -Path "Deadline*"
$fileName = "DeadlineClient-$schedulerVersion-windows-installer.exe"
Start-Process -FilePath $fileName -ArgumentList "--mode unattended --licensemode $schedulerLicense --repositorydir $schedulerRepositoryShare --dbsslcertificate $schedulerCertificatePath --dbsslpassword $userPassword" -Wait
Set-Location -Path ".."

if ($subnetName -eq "Workstation") {
  $fileName = "Blender-submitter-windows-installer.exe"
  $downloadUrl = "$storageContainerUrl/Deadline/Blender/Installers/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "--mode unattended" -Wait
  
  $fileName = "pcoip-agent-graphics_21.07.4.exe"
  $downloadUrl = "$storageContainerUrl/Teradici/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "/S /NoPostReboot /Force" -Wait
}

Copy-Item -Path $env:TMP -Destination TMP -Recurse
