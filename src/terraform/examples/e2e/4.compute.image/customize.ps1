param (
  [string] $subnetName,
  [string] $machineSize,
  [string] $userName,
  [string] $userPassword
)

Set-Location -Path "C:\Users\Default\Downloads"

# NVv3 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series
if (($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3")) -or
    ($machineSize.StartsWith("Standard_NC") -and $machineSize.EndsWith("T4_v3"))) {
  Write-Host "Customize (Start): GPU Driver (NVv3)"
  $fileName = "nvidia-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
  Write-Host "Customize (End): GPU Driver (NVv3)"
}

# NVv4 Series - https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v4")) {
  Write-Host "Customize (Start): GPU Driver (NVv4)"
  $fileName = "amd-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/S" -Wait
  Write-Host "Customize (End): GPU Driver (NVv4)"
}

Write-Host "Customize (Start): NFS Client"
DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
$registryKeyPath = "HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default"
New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0
Write-Host "Customize (End): NFS Client"

Write-Host "Customize (Start): CLI Tools"
$fileName = "az-cli.msi"
$downloadUrl = "https://aka.ms/installazurecliwindows"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
Start-Process -FilePath $fileName -ArgumentList "/quiet" -Wait
Write-Host "Customize (End): CLI Tools"

$storageContainerUrl = "https://az0.blob.core.windows.net/bin"
$storageContainerSas = "?sv=2020-08-04&st=2021-11-07T18%3A19%3A06Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=b4TcohYc%2FInzvG%2FQSxApyIaZlLT8Cl8ychUqZx6zNsg%3D"

$schedulerVersion = "10.1.19.4"
$schedulerLicense = "LicenseFree"
$schedulerShareName = "DeadlineRepository"
$schedulerDatabasePath = "C:\DeadlineDatabase"
$schedulerRepositoryPath = "C:\DeadlineRepository"

$fileName = "Deadline-$schedulerVersion-windows-installers.zip"
$downloadUrl = "$storageContainerUrl/Deadline/$fileName$storageContainerSas"
Invoke-WebRequest $downloadUrl -OutFile $fileName
Expand-Archive -Path $fileName

if ($subnetName -eq "Scheduler") {
  Write-Host "Customize (Start): Deadline Repository"
  netsh advfirewall firewall add rule name="Allow MongoDB Port" dir=in action=allow protocol=TCP localport=27100
  Set-Location -Path "Deadline*"
  $fileName = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
  Start-Process -FilePath $fileName -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --prefix $schedulerRepositoryPath --mongodir $schedulerDatabasePath --dbuser $userName --dbpassword $userPassword --requireSSL false" -Wait
  Set-Location -Path ".."
  Install-WindowsFeature -Name "FS-NFS-Service"
  New-NfsShare -Name $schedulerShareName -Path $schedulerRepositoryPath -Permission ReadWrite -AllowRootAccess $true
  Write-Host "Customize (End): Deadline Repository"
} else {
  Write-Host "Customize (Start): Blender"
  $fileName = "blender-2.93.5-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "/quiet /norestart" -Wait
  Write-Host "Customize (End): Blender"
}

if ($subnetName -eq "Farm") {
  Write-Host "Customize (Start): Metadata Service"
  $taskName = "Local Metadata Service Events"
  $taskArgument = "PowerShell -ExecutionPolicy Unrestricted -File C:\Windows\Temp\metadata.ps1"
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument $taskArgument
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minute 1) -At ([System.DateTime]::UtcNow) -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob
  Write-Host "Customize (End): Metadata Service"
}

Write-Host "Customize (Start): Deadline Client"
Set-Location -Path "Deadline*"
$fileName = "DeadlineClient-$schedulerVersion-windows-installer.exe"
Start-Process -FilePath $fileName -ArgumentList "--mode unattended --licensemode $schedulerLicense" -Wait
Set-Location -Path ".."
Write-Host "Customize (End): Deadline Client"

if ($subnetName -eq "Workstation") {
  Write-Host "Customize (Start): Blender Deadline Submitter"
  $fileName = "Blender-submitter-windows-installer.exe"
  $downloadUrl = "$storageContainerUrl/Deadline/Blender/Installers/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "--mode unattended" -Wait
  Write-Host "Customize (End): Blender Deadline Submitter"
  
  Write-Host "Customize (Start): Teradici PCoIP Agent"
  $fileName = "pcoip-agent-graphics_21.07.5.exe"
  $downloadUrl = "$storageContainerUrl/Teradici/$fileName$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $fileName
  Start-Process -FilePath $fileName -ArgumentList "/S /NoPostReboot /Force" -Wait
  Write-Host "Customize (End): Teradici PCoIP Agent"
}

Copy-Item -Path $env:TMP -Destination TMP -Recurse
