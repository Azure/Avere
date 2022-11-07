param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$storageContainerUrl = "https://azrender.blob.core.windows.net/bin"
$storageContainerSas = "?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D"

Write-Host "Customize (Start): Image Build Parameters"
$buildConfigBytes = [System.Convert]::FromBase64String($buildConfigEncoded)
$buildConfig = [System.Text.Encoding]::UTF8.GetString($buildConfigBytes) | ConvertFrom-Json
$machineType = $buildConfig.machineType
$machineSize = $buildConfig.machineSize
$renderManager = $buildConfig.renderManager
$renderEngines = $buildConfig.renderEngines -join ","
Write-Host "Machine Type: $machineType"
Write-Host "Machine Size: $machineSize"
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

Write-Host "Customize (Start): Resize OS Disk"
$osDriveLetter = "C"
$partitionSize = Get-PartitionSupportedSize -DriveLetter $osDriveLetter
Resize-Partition -DriveLetter $osDriveLetter -Size $partitionSize.SizeMax
Write-Host "Customize (End): Resize OS Disk"

Write-Host "Customize (Start): Git"
$versionInfo = "2.38.1"
$installFile = "Git-$versionInfo-64-bit.exe"
$downloadUrl = "$storageContainerUrl/Git/$versionInfo/$installFile$storageContainerSas"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Start-Process -FilePath $installFile -ArgumentList "/SILENT /NORESTART" -Wait
$toolPathGit = "C:\Program Files\Git\bin"
Write-Host "Customize (End): Git"

Write-Host "Customize (Start): Visual Studio"
$versionInfo = "2022"
$installFile = "VisualStudioSetup.exe"
$downloadUrl = "$storageContainerUrl/VS/$versionInfo/$installFile$storageContainerSas"
$workloadIds = "--add Microsoft.VisualStudio.Workload.ManagedDesktop;includeRecommended"
$workloadIds += " --add Microsoft.VisualStudio.Workload.NativeDesktop;includeRecommended"
$workloadIds += " --add Microsoft.VisualStudio.Workload.NativeGame;includeRecommended"
$workloadIds += " --add Microsoft.NetCore.Component.Runtime.3.1"
$workloadIds += " --add Component.Unreal"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Start-Process -FilePath $installFile -ArgumentList "--quiet --norestart $workloadIds" -Wait
$toolPathVSIX = "C:\Program Files\Microsoft Visual Studio\$versionInfo\Community\Common7\IDE"
$toolPathCMake = "C:\Program Files\Microsoft Visual Studio\$versionInfo\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$toolPathMSBuild = "C:\Program Files\Microsoft Visual Studio\$versionInfo\Community\Msbuild\Current\Bin"
Write-Host "Customize (End): Visual Studio"

#   NVv5 (https://learn.microsoft.com/azure/virtual-machines/nva10v5-series)
# NCT4v3 (https://learn.microsoft.com/azure/virtual-machines/nct4-v3-series)
#   NVv3 (https://learn.microsoft.com/azure/virtual-machines/nvv3-series)
if (($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v5")) -or
    ($machineSize.StartsWith("Standard_NC") -and $machineSize.EndsWith("_T4_v3")) -or
    ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3"))) {
  Write-Host "Customize (Start): NVIDIA GPU Driver (GRID)"
  $installFile = "nvidia-gpu-grid.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath $installFile -ArgumentList "/s /noreboot" -Wait
  Write-Host "Customize (End): NVIDIA GPU Driver (GRID)"
} elseif ($machineSize.StartsWith("Standard_N")) {
  Write-Host "Customize (Start): NVIDIA GPU Driver (CUDA)"
  $versionInfo = "11.8.0"
  $installFile = "cuda_${versionInfo}_522.06_windows.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/CUDA/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath $installFile -ArgumentList "/s /noreboot" -Wait
  Write-Host "Customize (End): NVIDIA GPU Driver (CUDA)"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installFile = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installFile /quiet /norestart" -Wait
  Write-Host "Customize (End): Azure CLI"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): NFS Server"
  Install-WindowsFeature -Name "FS-NFS-Service"
  Write-Host "Customize (End): NFS Server"
  Write-Host "Customize (Start): NFS Client"
  Install-WindowsFeature -Name "NFS-Client"
  Write-Host "Customize (End): NFS Client"
} else {
  Write-Host "Customize (Start): NFS Client"
  $installFile = "dism.exe"
  $featureName = "ClientForNFS-Infrastructure"
  Start-Process -FilePath $installFile -ArgumentList "/Enable-Feature /FeatureName:$featureName /Online /All /NoRestart" -Wait -Verb RunAs
  Write-Host "Customize (End): NFS Client"
}

$schedulerVersion = "10.1.23.6"
$schedulerPath = "C:\Program Files\Thinkbox\Deadline10\bin"
$schedulerDatabasePath = "C:\DeadlineDatabase"
$schedulerRepositoryPath = "C:\DeadlineRepository"
$schedulerCertificateFile = "Deadline10Client.pfx"
$schedulerRepositoryLocalMount = "S:\"
$schedulerRepositoryCertificate = "$schedulerRepositoryLocalMount$schedulerCertificateFile"

$rendererPathBlender = "C:\Program Files\Blender Foundation\Blender3"
$rendererPathPBRT3 = "C:\Program Files\PBRT\v3"
$rendererPathPBRT4 = "C:\Program Files\PBRT\v4"
$rendererPathUnreal = "C:\Program Files\Epic Games\Unreal5"
$rendererPathUnrealStream = "$rendererPathUnreal\Stream"
$rendererPathUnrealEditor = "$rendererPathUnreal\Engine\Binaries\Win64"

$rendererPaths = ""
if ($renderEngines -like "*Blender*") {
  $rendererPaths += ";$rendererPathBlender"
}
if ($renderEngines -like "*Unreal*") {
  $rendererPaths += ";$rendererPathUnreal"
}
setx PATH "$env:PATH;$schedulerPath$rendererPaths" /m

Write-Host "Customize (Start): Deadline Download"
$installFile = "Deadline-$schedulerVersion-windows-installers.zip"
$downloadUrl = "$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Expand-Archive -Path $installFile
Write-Host "Customize (End): Deadline Download"

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Deadline Repository"
  netsh advfirewall firewall add rule name="Allow Mongo Database" dir=in action=allow protocol=TCP localport=27100
  Set-Location -Path "Deadline*"
  $installFile = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
  Start-Process -FilePath $installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --mongodir $schedulerDatabasePath --prefix $schedulerRepositoryPath" -Wait
  Move-Item -Path $env:TMP\bitrock_installer.log -Destination $binDirectory\bitrock_installer_server.log
  Copy-Item -Path $schedulerDatabasePath\certs\$schedulerCertificateFile -Destination $schedulerRepositoryPath\$schedulerCertificateFile
  New-NfsShare -Name "DeadlineRepository" -Path $schedulerRepositoryPath -Permission ReadWrite
  Set-Location -Path $binDirectory
  Write-Host "Customize (End): Deadline Repository"
}

Write-Host "Customize (Start): Deadline Client"
netsh advfirewall firewall add rule name="Allow Deadline Worker" dir=in action=allow program="$schedulerPath\deadlineworker.exe"
netsh advfirewall firewall add rule name="Allow Deadline Monitor" dir=in action=allow program="$schedulerPath\deadlinemonitor.exe"
netsh advfirewall firewall add rule name="Allow Deadline Launcher" dir=in action=allow program="$schedulerPath\deadlinelauncher.exe"
Set-Location -Path "Deadline*"
$installFile = "DeadlineClient-$schedulerVersion-windows-installer.exe"
$installArgs = "--mode unattended"
if ($machineType -eq "Scheduler") {
  $installArgs = "$installArgs --slavestartup false --launcherservice false"
} else {
  if ($machineType -eq "Farm") {
    $workerStartup = "true"
  } else {
    $workerStartup = "false"
  }
  $installArgs = "$installArgs --slavestartup $workerStartup --launcherservice true"
}
Start-Process -FilePath $installFile -ArgumentList $installArgs -Wait
Move-Item -Path $env:TMP\bitrock_installer.log -Destination $binDirectory\bitrock_installer_client.log
Start-Process -FilePath "$schedulerPath\deadlinecommand.exe" -ArgumentList "-ChangeRepositorySkipValidation Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate ''" -Wait
Set-Location -Path $binDirectory
Write-Host "Customize (End): Deadline Client"

if ($renderEngines -like "*Blender*") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.3.1"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" /quiet /norestart') -Wait
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -like "*PBRT*") {
  Write-Host "Customize (Start): PBRT v3"
  $versionInfo = "v3"
  Start-Process -FilePath "$toolPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait
  Start-Process -FilePath "$toolPathCMake\cmake.exe" -ArgumentList "-B ""$rendererPathPBRT3"" -S $binDirectory\pbrt-$versionInfo" -Wait
  Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRT3\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait
  New-Item -ItemType SymbolicLink -Target "$rendererPathPBRT3\Release\pbrt.exe" -Path "C:\Program Files\pbrt3"
  Write-Host "Customize (End): PBRT v3"
  Write-Host "Customize (Start): PBRT v4"
  $versionInfo = "v4"
  Start-Process -FilePath "$toolPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait
  Start-Process -FilePath "$toolPathCMake\cmake.exe" -ArgumentList "-B ""$rendererPathPBRT4"" -S $binDirectory\pbrt-$versionInfo" -Wait
  Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRT4\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait
  New-Item -ItemType SymbolicLink -Target "$rendererPathPBRT4\Release\pbrt.exe" -Path "C:\Program Files\pbrt4"
  Write-Host "Customize (End): PBRT v4"
}

if ($renderEngines -like "*Unity*") {
  Write-Host "Customize (Start): Unity"
  $installFile = "UnityHubSetup.exe"
  $downloadUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/$installFile"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath $installFile -ArgumentList "/S" -Wait
  Write-Host "Customize (End): Unity"
}

if ($renderEngines -like "*Unreal*") {
  Write-Host "Customize (Start): Unreal"
  netsh advfirewall firewall add rule name="Allow Unreal Editor" dir=in action=allow program="$rendererPathUnrealEditor\UnrealEditor.exe"
  $installFile = "dism.exe"
  $featureName = "NetFX3"
  Start-Process -FilePath $installFile -ArgumentList "/Enable-Feature /FeatureName:$featureName /Online /All /NoRestart" -Wait -Verb RunAs
  $installFile = "UnrealEngine-5.1.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Expand-Archive -Path $installFile
  New-Item -ItemType Directory -Path "$rendererPathUnreal" -Force
  Move-Item -Path "Unreal*\Unreal*\*" -Destination "$rendererPathUnreal"
  $installFile = "$rendererPathUnreal\Setup.bat"
  $setupScript = Get-Content -Path $installFile
  $setupScript = $setupScript.Replace("/register", "/register /unattended")
  $setupScript = $setupScript.Replace("pause", "rem pause")
  Set-Content -Path $installFile -Value $setupScript
  Start-Process -FilePath "$installFile" -Wait
  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Unreal Project Files"
    & "$rendererPathUnreal\GenerateProjectFiles.bat"
    [System.Environment]::SetEnvironmentVariable("PATH", "$env:PATH;C:\Program Files\dotnet")
    Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList "-restore -p:Platform=Win64 -p:Configuration=""Development Editor"" ""$rendererPathUnreal\UE5.sln""" -Wait
    Write-Host "Customize (End): Unreal Project Files"
    Write-Host "Customize (Start): Unreal Visual Studio Plugin"
    $installFile = "UnrealVS.vsix"
    Start-Process -FilePath "$toolPathVSIX\VSIXInstaller.exe" -ArgumentList "/quiet /admin ""$rendererPathUnreal\Engine\Extras\UnrealVS\$installFile""" -Wait
    Write-Host "Customize (End): Unreal Visual Studio Plugin"
    Write-Host "Customize (Start): Unreal Editor Shortcut"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Epic Unreal Editor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$rendererPathUnrealEditor"
    $shortcut.TargetPath = "$rendererPathUnrealEditor\UnrealEditor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Unreal Editor Shortcut"
  }
  Write-Host "Customize (End): Unreal"
}

if ($renderEngines -like "*Unreal,PixelStream*") {
  Write-Host "Customize (Start): Unreal Pixel Streaming"
  $installFile = "PixelStreamingInfrastructure-UE5.1.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Expand-Archive -Path $installFile
  New-Item -ItemType Directory -Path "$rendererPathUnrealStream" -Force
  Move-Item -Path "PixelStreaming*\PixelStreaming*\*" -Destination "$rendererPathUnrealStream"
  $installFile = "setup.bat"
  Set-Location -Path "$rendererPathUnrealStream/SignallingWebServer/platform_scripts/cmd"
  Start-Process -FilePath $installFile -Wait
  $installFile = "setup.bat"
  Set-Location -Path "$rendererPathUnrealStream/MatchMaker/platform_scripts/cmd"
  Start-Process -FilePath $installFile -Wait
  Set-Location -Path $binDirectory
  Write-Host "Customize (End): Unreal Pixel Streaming"
}

if ($machineType -eq "Farm") {
  if (Test-Path -Path "C:\Windows\Temp\onTerminate.ps1") {
    Write-Host "Customize (Start): CycleCloud Event Handler"
    New-Item -ItemType Directory -Path "C:\cycle\jetpack\scripts" -Force
    Copy-Item -Path "C:\Windows\Temp\onTerminate.ps1" -Destination "C:\cycle\jetpack\scripts\onPreempt.ps1"
    Copy-Item -Path "C:\Windows\Temp\onTerminate.ps1" -Destination "C:\cycle\jetpack\scripts\onTerminate.ps1"
    Write-Host "Customize (End): CycleCloud Event Handler"
  }
  Write-Host "Customize (Start): Privacy Experience"
  $registryKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
  New-Item -ItemType Directory -Path $registryKeyPath -Force
  New-ItemProperty -Path $registryKeyPath -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force
  Write-Host "Customize (End): Privacy Experience"
}

if ($machineType -eq "Workstation") {
  Write-Host "Customize (Start): Teradici PCoIP Agent"
  $versionInfo = "22.09.0"
  $installFile = "pcoip-agent-graphics_$versionInfo.exe"
  $downloadUrl = "$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath $installFile -ArgumentList "/S /NoPostReboot /Force" -Wait
  Write-Host "Customize (End): Teradici PCoIP Agent"

  Write-Host "Customize (Start): V-Ray Benchmark"
  $versionInfo = "5.02.00"
  $installFile = "vray-benchmark-$versionInfo.exe"
  $downloadUrl = "$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  $installFile = "vray-benchmark-$versionInfo-cli.exe"
  $downloadUrl = "$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Write-Host "Customize (End): V-Ray Benchmark"

  Write-Host "Customize (Start): Cinebench"
  $versionInfo = "R23"
  $installFile = "Cinebench$versionInfo.zip"
  $downloadUrl = "$storageContainerUrl/Cinebench/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Cinebench"

  Write-Host "Customize (Start): Deadline Monitor Shortcut"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $schedulerPath
  $shortcut.TargetPath = "$schedulerPath\deadlinemonitor.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Deadline Monitor Shortcut"
}
