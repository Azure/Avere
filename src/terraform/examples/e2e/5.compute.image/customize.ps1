param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$storageContainerUrl = "https://azrender.blob.core.windows.net/bin"
$storageContainerSas = "?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D"

Write-Host "Customize (Start): Resize OS Disk"
$osDriveLetter = "C"
$partitionSize = Get-PartitionSupportedSize -DriveLetter $osDriveLetter
Resize-Partition -DriveLetter $osDriveLetter -Size $partitionSize.SizeMax
Write-Host "Customize (End): Resize OS Disk"

Write-Host "Customize (Start): Git"
$versionInfo = "2.38.0"
$installFile = "Git-$versionInfo-64-bit.exe"
$downloadUrl = "$storageContainerUrl/Git/$versionInfo/$installFile$storageContainerSas"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Start-Process -FilePath .\$installFile -ArgumentList "/SILENT /NORESTART" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
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
Start-Process -FilePath .\$installFile -ArgumentList "--quiet --norestart $workloadIds" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
$toolPathVSIX = "C:\Program Files\Microsoft Visual Studio\$versionInfo\Community\Common7\IDE"
$toolPathCMake = "C:\Program Files\Microsoft Visual Studio\$versionInfo\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$toolPathMSBuild = "C:\Program Files\Microsoft Visual Studio\$versionInfo\Community\Msbuild\Current\Bin"
Write-Host "Customize (End): Visual Studio"

Write-Host "Customize (Start): Image Build Parameters"
$buildConfigBytes = [System.Convert]::FromBase64String($buildConfigEncoded)
$buildConfig = [System.Text.Encoding]::UTF8.GetString($buildConfigBytes) | ConvertFrom-Json
$machineType = $buildConfig.machineType
$machineSize = $buildConfig.machineSize
$renderEngines = $buildConfig.renderEngines -join ","
Write-Host "Machine Type: $machineType"
Write-Host "Machine Size: $machineSize"
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

#   NVv3 (https://learn.microsoft.com/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://learn.microsoft.com/azure/virtual-machines/nct4-v3-series)
#   NVv5 (https://learn.microsoft.com/azure/virtual-machines/nva10v5-series)
if (($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3")) -or
    ($machineSize.StartsWith("Standard_NC") -and $machineSize.EndsWith("_T4_v3")) -or
    ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v5"))) {
  Write-Host "Customize (Start): NVIDIA GPU GRID Driver"
  $installFile = "nvidia-gpu-grid.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/s /noreboot" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): NVIDIA GPU GRID Driver"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installFile = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installFile /quiet /norestart" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
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

$rendererPaths = ""
$rendererPathBlender = "C:\Program Files\Blender Foundation\Blender3"
$rendererPathPBRT = "C:\Program Files\PBRT3"
$rendererPathUnreal = "C:\Program Files\Epic Games\Unreal5"
$rendererPathUnrealStream = "$rendererPathUnreal\Stream"
$rendererPathUnrealEditor = "$rendererPathUnreal\Engine\Binaries\Win64"
$rendererPathMaya = "C:\Program Files\Autodesk\Maya2023"
$rendererPath3DSMax = "C:\Program Files\Autodesk\3ds Max 2023"
$rendererPathHoudini = "C:\Program Files\Side Effects Software\Houdini19"
if ($renderEngines -like "*Blender*") {
  $rendererPaths += ";$rendererPathBlender"
}
if ($renderEngines -like "*PBRT*") {
  $rendererPaths += ";$rendererPathPBRT\Release"
}
if ($renderEngines -like "*Unreal*") {
  $rendererPaths += ";$rendererPathUnreal"
}
if ($renderEngines -like "*Maya*") {
  $rendererPaths += ";$rendererPathMaya"
}
if ($renderEngines -like "*3DSMax*") {
  $rendererPaths += ";$rendererPath3DSMax"
}
if ($renderEngines -like "*Houdini*") {
  $rendererPaths += ";$rendererPathHoudini\bin"
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
  Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --dbhost localhost --mongodir $schedulerDatabasePath --prefix $schedulerRepositoryPath" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  $installFileLog = "$env:TMP\bitrock_installer.log"
  Copy-Item -Path $installFileLog -Destination $binDirectory\bitrock_installer_server.log
  Remove-Item -Path $installFileLog -Force
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
Start-Process -FilePath .\$installFile -ArgumentList $installArgs -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
Copy-Item -Path $env:TMP\bitrock_installer.log -Destination $binDirectory\bitrock_installer_client.log
$deadlineCommandName = "ChangeRepositorySkipValidation"
Start-Process -FilePath "$schedulerPath\deadlinecommand.exe" -ArgumentList "-$deadlineCommandName Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate ''" -Wait -RedirectStandardOutput "$deadlineCommandName-output.txt" -RedirectStandardError "$deadlineCommandName-error.txt"
Set-Location -Path $binDirectory
Write-Host "Customize (End): Deadline Client"

if ($renderEngines -like "*Blender*") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.3.1"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" /quiet /norestart') -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -like "*PBRT*") {
  Write-Host "Customize (Start): PBRT"
  $versionInfo = "v3"
  Start-Process -FilePath "$toolPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait
  Start-Process -FilePath "$toolPathCMake\cmake.exe" -ArgumentList "-S $binDirectory\pbrt-$versionInfo -B ""$rendererPathPBRT""" -Wait -RedirectStandardOutput "cmake-pbrt-$versionInfo.output.txt" -RedirectStandardError "cmake-pbrt-$versionInfo.error.txt"
  Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRT\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "msbuild-pbrt-$versionInfo.output.txt" -RedirectStandardError "msbuild-pbrt-$versionInfo.error.txt"
  Write-Host "Customize (End): PBRT"
}

if ($renderEngines -like "*Unity*") {
  Write-Host "Customize (Start): Unity"
  $versionInfo = "3.0"
  $installFile = "UnityHubSetup.exe"
  $downloadUrl = "$storageContainerUrl/Unity/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/S" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Unity"
}

if ($renderEngines -like "*Unreal*") {
  Write-Host "Customize (Start): Unreal Engine"
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
  Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Unreal Project Files"
    & "$rendererPathUnreal\GenerateProjectFiles.bat"
    [System.Environment]::SetEnvironmentVariable("PATH", "$env:PATH;C:\Program Files\dotnet")
    Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList "-restore -p:Platform=Win64 -p:Configuration=""Development Editor"" ""$rendererPathUnreal\UE5.sln""" -Wait -RedirectStandardOutput "msbuild-ue5.output.txt" -RedirectStandardError "msbuild-ue5.error.txt"
    Write-Host "Customize (End): Unreal Project Files"
    Write-Host "Customize (Start): Unreal Visual Studio Plugin"
    $installFile = "UnrealVS.vsix"
    Start-Process -FilePath "$toolPathVSIX\VSIXInstaller.exe" -ArgumentList "/quiet /admin ""$rendererPathUnreal\Engine\Extras\UnrealVS\$installFile""" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
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
  Write-Host "Customize (End): Unreal Engine"
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
  Start-Process -FilePath ./$installFile -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  $installFile = "setup.bat"
  Set-Location -Path "$rendererPathUnrealStream/MatchMaker/platform_scripts/cmd"
  Start-Process -FilePath ./$installFile -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Set-Location -Path $binDirectory
  Write-Host "Customize (End): Unreal Pixel Streaming"
}

if ($renderEngines -like "*Maya*") {
  Write-Host "Customize (Start): Maya"
  $versionInfo = "2023"
  $installFile = "Autodesk_Maya_${versionInfo}_ML_Windows_64bit.zip"
  $downloadUrl = "$storageContainerUrl/Maya/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Expand-Archive -Path $installFile
  Start-Process -FilePath ".\Autodesk_Maya*\Setup.exe" -ArgumentList "--silent" -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Start-Sleep -Seconds 360
  Write-Host "Customize (End): Maya"
}

if ($renderEngines -like "*3DSMax*") {
  Write-Host "Customize (Start): 3DS Max"
  $versionInfo = "2023"
  $installFile = "Autodesk_3ds_Max_${versionInfo}_EFGJKPS_Win_64bit.zip"
  $downloadUrl = "$storageContainerUrl/3DSMax/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Expand-Archive -Path $installFile
  Start-Process -FilePath ".\Autodesk_3ds_Max*\Setup.exe" -ArgumentList "--silent" -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Start-Sleep -Seconds 360
  Write-Host "Customize (End): 3DS Max"
}

if ($renderEngines -like "*Houdini*") {
  Write-Host "Customize (Start): Houdini"
  $versionInfo = "19.0.561"
  $versionEULA = "2021-10-13"
  $installFile = "houdini-$versionInfo-win64-vc142.exe"
  $downloadUrl = "$storageContainerUrl/Houdini/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  if ($machineType -eq "Workstation") {
    $installArgs = "/MainApp=Yes"
  } else {
    $installArgs = "/HoudiniEngineOnly=Yes"
  }
  if ($renderEngines -like "*Unreal*") {
    $installArgs += " /EngineUnreal=Yes"
  }
  if ($renderEngines -like "*Maya*") {
    $installArgs += " /EngineMaya=Yes"
  }
  if ($renderEngines -like "*3DSMax*") {
    $installArgs += " /Engine3dsMax=Yes"
  }
  Start-Process -FilePath .\$installFile -ArgumentList "/S /AcceptEULA=$versionEULA /InstallDir=$rendererPathHoudini $installArgs" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Houdini"
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
  Start-Process -FilePath .\$installFile -ArgumentList "/S /NoPostReboot /Force" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Teradici PCoIP Agent"

  Write-Host "Customize (Start): Deadline Monitor Shortcut"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $schedulerPath
  $shortcut.TargetPath = "$schedulerPath\deadlinemonitor.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Deadline Monitor Shortcut"

  # Write-Host "Customize (Start): Cinebench"
  # $versionInfo = "R23"
  # $installFile = "Cinebench$versionInfo.zip"
  # $downloadUrl = "$storageContainerUrl/Cinebench/$versionInfo/$installFile$storageContainerSas"
  # Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  # Expand-Archive -Path $installFile
  # Write-Host "Customize (End): Cinebench"

  # Write-Host "Customize (Start): VRay Benchmark"
  # $versionInfo = "5.02.00"
  # $installFile = "vray-benchmark-$versionInfo.exe"
  # $downloadUrl = "$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  # Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  # $installFile = "vray-benchmark-$versionInfo-cli.exe"
  # $downloadUrl = "$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  # Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  # Write-Host "Customize (End): VRay Benchmark"
}
