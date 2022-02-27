param (
  [string] $serviceUser,
  [string] $servicePassword,
  [string] $subnetName,
  [string] $machineSize,
  [string] $renderEngines
)

$homeDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $homeDirectory

#   NVv3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nct4-v3-series)
if (($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3")) -or
    ($machineSize.StartsWith("Standard_NC") -and $machineSize.EndsWith("T4_v3"))) {
  Write-Host "Customize (Start): GPU Driver (NVv3)"
  $installFile = "nvidia-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/s /noreboot" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
  Write-Host "Customize (End): GPU Driver (NVv3)"
}

# NVv4 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series)
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v4")) {
  Write-Host "Customize (Start): GPU Driver (NVv4)"
  $installFile = "amd-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/S" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
  Write-Host "Customize (End): GPU Driver (NVv4)"
}

if ($subnetName -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $fileName = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl
  Start-Process -FilePath $fileName -ArgumentList "/quiet /norestart" -Wait
  Write-Host "Customize (End): Azure CLI"
} else {
  Write-Host "Customize (Start): NFS Client"
  $installFile = "dism.exe"
  $featureName = "ClientForNFS-Infrastructure"
  Start-Process -FilePath $installFile -ArgumentList "/Enable-Feature /FeatureName:$featureName /Online /All /NoRestart" -Wait -Verb RunAs
  $registryKeyPath = "HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default"
  New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
  New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0
  Write-Host "Customize (End): NFS Client"
}

$storageContainerUrl = "https://az0.blob.core.windows.net/bin"
$storageContainerSas = "?sv=2020-08-04&st=2021-11-07T18%3A19%3A06Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=b4TcohYc%2FInzvG%2FQSxApyIaZlLT8Cl8ychUqZx6zNsg%3D"

$schedulerVersion = "10.1.20.2"
$schedulerLicense = "LicenseFree"
$schedulerDatabasePath = "C:\DeadlineDatabase"
$schedulerRepositoryPath = "C:\DeadlineRepository"

$rendererPaths = ""
$schedulerPath = "C:\Program Files\Thinkbox\Deadline10\bin"
$rendererPathBlender = "C:\Program Files\Blender Foundation\Blender"
$rendererPathMaya = "C:\Program Files\Autodesk\Maya2022"
$rendererPathUnreal = "C:\Unreal"
if ($renderEngines -like "*Blender*") {
  $rendererPaths += ";$rendererPathBlender"
}
if ($renderEngines -like "*Maya*") {
  $rendererPaths += ";$rendererPathMaya"
}
if ($renderEngines -like "*Unreal*") {
  $rendererPaths += ";$rendererPathUnreal"
}
setx PATH "$env:PATH;$schedulerPath$rendererPaths" /m

Write-Host "Customize (Start): Deadline Download"
$installFile = "Deadline-$schedulerVersion-windows-installers.zip"
$downloadUrl = "$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
Invoke-WebRequest $downloadUrl -OutFile $installFile
Expand-Archive -Path $installFile
Write-Host "Customize (End): Deadline Download"

Write-Host "Customize (Start): Deadline Client"
netsh advfirewall firewall add rule name="Allow Deadline Worker" dir=in action=allow program="$schedulerPath\deadlineworker.exe"
netsh advfirewall firewall add rule name="Allow Deadline Monitor" dir=in action=allow program="$schedulerPath\deadlinemonitor.exe"
netsh advfirewall firewall add rule name="Allow Deadline Launcher" dir=in action=allow program="$schedulerPath\deadlinelauncher.exe"
Set-Location -Path "Deadline*"
$installFile = "DeadlineClient-$schedulerVersion-windows-installer.exe"
if ($subnetName -eq "Scheduler") {
  $clientArgs = "--slavestartup false --launcherservice false"
} else {
  New-LocalUser -Name $userName -Password (ConvertTo-SecureString -String $servicePassword -AsPlainText -Force)
  if ($subnetName -eq "Farm") {
    $workerStartup = "true"
  } else {
    $workerStartup = "false"
  }
  $clientArgs = "--slavestartup $workerStartup --launcherservice true --serviceuser $userName --servicepassword $servicePassword"
}
Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --licensemode $schedulerLicense $clientArgs" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
$installFile = "$schedulerPath\deadlinecommand.exe"
Start-Process -FilePath "$installFile" -ArgumentList "-ChangeRepositorySkipValidation Direct S:\" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
Start-Process -FilePath "$installFile" -ArgumentList "-ChangeLicenseMode $schedulerLicense" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
Set-Location -Path $homeDirectory
Write-Host "Customize (End): Deadline Client"

if ($subnetName -eq "Scheduler") {
  Write-Host "Customize (Start): Deadline Repository"
  Set-Location -Path "Deadline*"
  $installFile = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
  Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --prefix $schedulerRepositoryPath --mongodir $schedulerDatabasePath --dbuser $userName --dbpassword $servicePassword --requireSSL false" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
  Set-Location -Path $homeDirectory
  Install-WindowsFeature -Name "NFS-Client"
  Install-WindowsFeature -Name "FS-NFS-Service"
  New-NfsShare -Name "DeadlineRepository" -Path $schedulerRepositoryPath -Permission ReadWrite
  Write-Host "Customize (End): Deadline Repository"
}

if ($renderEngines -like "*Blender*") {
  Write-Host "Customize (Start): Blender"
  $rendererVersion = "3.0.1"
  $installFile = "blender-$rendererVersion-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$rendererVersion/$installFile$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $installFile
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" /quiet /norestart') -Wait -RedirectStandardError $installFile.Replace(".msi", "-error.txt") -RedirectStandardOutput $installFile.Replace(".msi", "-output.txt")
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -like "*Maya*") {
  Write-Host "Customize (Start): Maya"
  $rendererVersion = "2022"
  $installFile = "Autodesk_Maya_2022_3_ML_Windows_64bit_di_ML_setup_webinstall.exe"
  $downloadUrl = "$storageContainerUrl/Maya/$rendererVersion/$installFile$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $installFile
  Start-Process -FilePath .\$installFile -ArgumentList "--silent" -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
  Start-Sleep -Seconds 600
  Write-Host "Customize (End): Maya"
}

if ($renderEngines -like "*Unreal*") {
  Write-Host "Customize (Start): Unreal"
  $installFile = "dism.exe"
  $featureName = "NetFX3"
  Start-Process -FilePath $installFile -ArgumentList "/Enable-Feature /FeatureName:$featureName /Online /All /NoRestart" -Wait -Verb RunAs
  $rendererVersion = "5.0.0"
  $installFile = "UnrealEngine-$rendererVersion-early-access-2.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$rendererVersion/$installFile$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $installFile
  Expand-Archive -Path $installFile -DestinationPath $rendererPathUnreal
  Move-Item -Path "$rendererPathUnreal\UnrealEngine*\*" -Destination $rendererPathUnreal
  $installFile = "$rendererPathUnreal\Setup.bat"
  $setupScript = Get-Content -Path $installFile
  $setupScript = $setupScript.Replace("/register", "/register /unattended")
  $setupScript = $setupScript.Replace("pause", "rem pause")
  Set-Content -Path $installFile -Value $setupScript
  Start-Process -FilePath $installFile -ArgumentList "--force" -Wait -RedirectStandardError $installFile.Replace(".bat", "-error.txt") -RedirectStandardOutput $installFile.Replace(".bat", "-output.txt")
  Write-Host "Customize (End): Unreal"
}

if ($subnetName -eq "Farm") {
  Write-Host "Customize (Start): Privacy Experience"
  $registryKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
  New-Item -Path $registryKeyPath -Force
  New-ItemProperty -Path $registryKeyPath -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force
  Write-Host "Customize (End): Privacy Experience"   
}

if ($subnetName -eq "Workstation") {
  Write-Host "Customize (Start): Deadline Monitor Shortcut"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $schedulerPath
  $shortcut.TargetPath = "$schedulerPath\deadlinemonitor.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Deadline Monitor Shortcut"

  Write-Host "Customize (Start): Blender Shortcut"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Blender.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $rendererPathBlender
  $shortcut.TargetPath = "$rendererPathBlender\blender.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Blender Shortcut"

  Write-Host "Customize (Start): Teradici PCoIP Agent"
  $installFile = "pcoip-agent-graphics_21.07.7.exe"
  $downloadUrl = "$storageContainerUrl/Teradici/$installFile$storageContainerSas"
  Invoke-WebRequest $downloadUrl -OutFile $installFile
  Start-Process -FilePath .\$installFile -ArgumentList "/S /NoPostReboot /Force" -Wait -RedirectStandardError $installFile.Replace(".exe", "-error.txt") -RedirectStandardOutput $installFile.Replace(".exe", "-output.txt")
  Write-Host "Customize (End): Teradici PCoIP Agent"
}
