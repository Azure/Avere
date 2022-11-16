param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$binPaths = ""
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
$versionInfo = "2.38.1"
$installFile = "Git-$versionInfo-64-bit.exe"
$downloadUrl = "$storageContainerUrl/Git/$versionInfo/$installFile$storageContainerSas"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
Start-Process -FilePath $installFile -ArgumentList "/SILENT /NORESTART" -Wait
$binPathGit = "C:\Program Files\Git\bin"
$binPaths += ";$binPathGit"
Write-Host "Customize (End): Git"

Write-Host "Customize (Start): Visual Studio Build Tools"
$versionInfo = "2022"
$installFile = "vs_buildtools.exe"
$downloadUrl = "https://aka.ms/vs/17/release/$installFile"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
$componentIds = "--add Microsoft.VisualStudio.Component.Windows11SDK.22621"
$componentIds += " --add Microsoft.VisualStudio.Component.VC.CMake.Project"
Start-Process -FilePath $installFile -ArgumentList "--quiet --norestart $componentIds" -Wait
$binPathCMake = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$binPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\MSBuild\Current\Bin"
$binPaths += ";$binPathCMake;$binPathMSBuild"
Write-Host "Customize (End): Visual Studio Build Tools"

Write-Host "Customize (Start): Python"
$versionInfo = "3.11.0"
$installFile = "python-$versionInfo-amd64.exe"
$downloadUrl = "https://www.python.org/ftp/python/$versionInfo/$installFile"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
Start-Process -FilePath $installFile -ArgumentList "/quiet" -Wait
Write-Host "Customize (End): Python"

Write-Host "Customize (Start): Image Build Parameters"
$buildConfigBytes = [System.Convert]::FromBase64String($buildConfigEncoded)
$buildConfig = [System.Text.Encoding]::UTF8.GetString($buildConfigBytes) | ConvertFrom-Json
$machineType = $buildConfig.machineType
$gpuPlatform = $buildConfig.gpuPlatform
$renderManager = $buildConfig.renderManager
$renderEngines = $buildConfig.renderEngines
Write-Host "Machine Type: $machineType"
Write-Host "GPU Platform: $gpuPlatform"
Write-Host "Render Manager: $renderManager"
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

if ($gpuPlatform -contains "GRID") {
  Write-Host "Customize (Start): NVIDIA GPU (GRID)"
  $installFile = "nvidia-gpu-grid.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath ./$installFile -ArgumentList "-s -n" -Wait -RedirectStandardOutput "nvidia-grid.output.txt" -RedirectStandardError "nvidia-grid.error.txt"
  Write-Host "Customize (End): NVIDIA GPU (GRID)"
}

if ($gpuPlatform -contains "CUDA" -or $gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA GPU (CUDA)"
  $versionInfo = "11.8.0"
  $installFile = "cuda_${versionInfo}_522.06_windows.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/CUDA/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath ./$installFile -ArgumentList "-s -n" -Wait -RedirectStandardOutput "nvidia-cuda.output.txt" -RedirectStandardError "nvidia-cuda.error.txt"
  [System.Environment]::SetEnvironmentVariable("CUDA_TOOLKIT_ROOT_DIR", "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8", [System.EnvironmentVariableTarget]::Machine)
  Write-Host "Customize (End): NVIDIA GPU (CUDA)"
}

if ($gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA GPU (OptiX)"
  $versionInfo = "7.6.0"
  $installFile = "NVIDIA-OptiX-SDK-$versionInfo-win64-31894579.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/OptiX/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath ./$installFile -ArgumentList "/s /n" -Wait -RedirectStandardOutput "nvidia-optix.output.txt" -RedirectStandardError "nvidia-optix.error.txt"
  $sdkDirectory = "C:\ProgramData\NVIDIA Corporation\OptiX SDK $versionInfo\SDK"
  $buildDirectory = "$sdkDirectory\build"
  New-Item -ItemType Directory $buildDirectory -Force
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$buildDirectory"" -S ""$sdkDirectory""" -Wait -RedirectStandardOutput "nvidia-optix-cmake.output.txt" -RedirectStandardError "nvidia-optix-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$buildDirectory\OptiX-Samples.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "nvidia-optix-msbuild.output.txt" -RedirectStandardError "nvidia-optix-msbuild.error.txt"
  $binPaths += ";$buildDirectory\bin\Release"
  Write-Host "Customize (End): NVIDIA GPU (OptiX)"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installFile = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installFile /quiet /norestart" -Wait
  Write-Host "Customize (End): Azure CLI"

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

if ($renderManager -eq "Deadline") {
  $schedulerVersion = "10.1.23.6"
  $schedulerPath = "C:\Program Files\Thinkbox\Deadline10\bin"
  $schedulerDatabasePath = "C:\DeadlineDatabase"
  $schedulerRepositoryPath = "C:\DeadlineRepository"
  $schedulerCertificateFile = "Deadline10Client.pfx"
  $schedulerRepositoryLocalMount = "S:\"
  $schedulerRepositoryCertificate = "$schedulerRepositoryLocalMount$schedulerCertificateFile"
  $binPaths += ";$schedulerPath"
}

$rendererPathBlender = "C:\Program Files\Blender Foundation\Blender3"
$rendererPathPBRT3 = "C:\Program Files\PBRT\v3"
$rendererPathPBRT4 = "C:\Program Files\PBRT\v4"
$rendererPathUnreal = "C:\Program Files\Epic Games\Unreal5"
$rendererPathUnrealStream = "$rendererPathUnreal\Stream"
$rendererPathUnrealEditor = "$rendererPathUnreal\Engine\Binaries\Win64"

if ($renderEngines -contains "Blender") {
  $binPaths += ";$rendererPathBlender"
}
if ($renderEngines -contains "Unreal") {
  $binPaths += ";$rendererPathUnreal"
}
setx PATH "$env:PATH$binPaths" /m

if ($renderManager -eq "Deadline") {
  Write-Host "Customize (Start): Deadline Download"
  $installFile = "Deadline-$schedulerVersion-windows-installers.zip"
  $downloadUrl = "$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
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
}

if ($renderEngines -contains "Blender") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.3.1"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" /quiet /norestart') -Wait
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -contains "PBRT") {
  Write-Host "Customize (Start): PBRT v3"
  $versionInfo = "v3"
  Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait -RedirectStandardOutput "pbrt-$versionInfo-git.output.txt" -RedirectStandardError "pbrt-$versionInfo-git.error.txt"
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$rendererPathPBRT3"" -S $binDirectory\pbrt-$versionInfo" -Wait -RedirectStandardOutput "pbrt-$versionInfo-cmake.output.txt" -RedirectStandardError "pbrt-$versionInfo-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRT3\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "pbrt-$versionInfo-msbuild.output.txt" -RedirectStandardError "pbrt-$versionInfo-msbuild.error.txt"
  New-Item -ItemType SymbolicLink -Target "$rendererPathPBRT3\Release\pbrt.exe" -Path "C:\Windows\pbrt3"
  Write-Host "Customize (End): PBRT v3"

  Write-Host "Customize (Start): PBRT v4"
  $versionInfo = "v4"
  Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait -RedirectStandardOutput "pbrt-$versionInfo-git.output.txt" -RedirectStandardError "pbrt-$versionInfo-git.error.txt"
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$rendererPathPBRT4"" -S $binDirectory\pbrt-$versionInfo" -Wait -RedirectStandardOutput "pbrt-$versionInfo-cmake.output.txt" -RedirectStandardError "pbrt-$versionInfo-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRT4\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "pbrt-$versionInfo-msbuild.output.txt" -RedirectStandardError "pbrt-$versionInfo-msbuild.error.txt"
  New-Item -ItemType SymbolicLink -Target "$rendererPathPBRT4\Release\pbrt.exe" -Path "C:\Windows\pbrt4"
  Write-Host "Customize (End): PBRT v4"
}

if ($renderEngines -contains "PBRT.Moana") {
  Write-Host "Customize (Start): PBRT (Moana Island)"
  $dataDirectory = "moana"
  New-Item -ItemType Directory -Path $dataDirectory -Force
  $installFile = "island-basepackage-v1.1.tgz"
  $downloadUrl = "$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  tar -xzf $installFile -C $dataDirectory
  $installFile = "island-pbrt-v1.1.tgz"
  $downloadUrl = "$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  tar -xzf $installFile -C $dataDirectory
  $installFile = "island-pbrtV4-v2.0.tgz"
  $downloadUrl = "$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  tar -xzf $installFile -C $dataDirectory
  Write-Host "Customize (End): PBRT (Moana Island)"
}

if ($renderEngines -contains "Unity") {
  Write-Host "Customize (Start): Unity"
  $installFile = "UnityHubSetup.exe"
  $downloadUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/$installFile"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath $installFile -ArgumentList "/S" -Wait
  Write-Host "Customize (End): Unity"
}

if ($renderEngines -contains "Unreal") {
  Write-Host "Customize (Start): Unreal"
  netsh advfirewall firewall add rule name="Allow Unreal Editor" dir=in action=allow program="$rendererPathUnrealEditor\UnrealEditor.exe"
  $installFile = "dism.exe"
  $featureName = "NetFX3"
  Start-Process -FilePath $installFile -ArgumentList "/Enable-Feature /FeatureName:$featureName /Online /All /NoRestart" -Wait -Verb RunAs
  $installFile = "UnrealEngine-5.1.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
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
    [System.Environment]::SetEnvironmentVariable("PATH", "$env:PATH;C:\Program Files\dotnet", [System.EnvironmentVariableTarget]::Machine)
    Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList "-restore -p:Platform=Win64 -p:Configuration=""Development Editor"" ""$rendererPathUnreal\UE5.sln""" -Wait
    Write-Host "Customize (End): Unreal Project Files"
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

if ($renderEngines -contains "Unreal.PixelStream") {
  Write-Host "Customize (Start): Unreal Pixel Streaming"
  $installFile = "PixelStreamingInfrastructure-UE5.1.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
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
  Write-Host "Customize (Start): Teradici PCoIP"
  $versionInfo = "22.09.2"
  $installFile = "pcoip-agent-graphics_$versionInfo.exe"
  $downloadUrl = "$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Start-Process -FilePath $installFile -ArgumentList "/S /NoPostReboot /Force" -Wait
  Write-Host "Customize (End): Teradici PCoIP"

  Write-Host "Customize (Start): V-Ray Benchmark"
  $versionInfo = "5.02.00"
  $installFile = "vray-benchmark-$versionInfo.exe"
  $downloadUrl = "$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  $installFile = "vray-benchmark-$versionInfo-cli.exe"
  $downloadUrl = "$storageContainerUrl/VRay/Benchmark/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
  Write-Host "Customize (End): V-Ray Benchmark"

  Write-Host "Customize (Start): Cinebench"
  $versionInfo = "R23"
  $installFile = "Cinebench$versionInfo.zip"
  $downloadUrl = "$storageContainerUrl/Cinebench/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $installFile -UseBasicParsing
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