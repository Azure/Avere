param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"

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
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
Start-Process -FilePath .\$installFile -ArgumentList "/silent /norestart" -Wait -RedirectStandardOutput "git.output.txt" -RedirectStandardError "git.error.txt"
$binPathGit = "C:\Program Files\Git\bin"
$binPaths += ";$binPathGit"
Write-Host "Customize (End): Git"

Write-Host "Customize (Start): Visual Studio Build Tools"
$versionInfo = "2022"
$installFile = "vs_BuildTools.exe"
$downloadUrl = "$storageContainerUrl/VS/$versionInfo/$installFile$storageContainerSas"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
$componentIds = "--add Microsoft.VisualStudio.Component.Windows11SDK.22621"
$componentIds += " --add Microsoft.VisualStudio.Component.VC.CMake.Project"
$componentIds += " --add Microsoft.Component.MSBuild"
Start-Process -FilePath .\$installFile -ArgumentList "$componentIds --quiet --norestart" -Wait -RedirectStandardOutput "vs-build-tools.output.txt" -RedirectStandardError "vs-build-tools.error.txt"
$binPathCMake = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$binPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\MSBuild\Current\Bin"
$binPaths += ";$binPathCMake;$binPathMSBuild"
Write-Host "Customize (End): Visual Studio Build Tools"

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
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "-s -n" -Wait -RedirectStandardOutput "nvidia-grid.output.txt" -RedirectStandardError "nvidia-grid.error.txt"
  Write-Host "Customize (End): NVIDIA GPU (GRID)"
}

if ($gpuPlatform -contains "CUDA" -or $gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA GPU (CUDA)"
  $versionInfo = "11.8.0"
  $installFile = "cuda_${versionInfo}_522.06_windows.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/CUDA/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "-s -n" -Wait -RedirectStandardOutput "nvidia-cuda.output.txt" -RedirectStandardError "nvidia-cuda.error.txt"
  [System.Environment]::SetEnvironmentVariable("CUDA_TOOLKIT_ROOT_DIR", "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8", [System.EnvironmentVariableTarget]::Machine)
  Write-Host "Customize (End): NVIDIA GPU (CUDA)"
}

if ($gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA GPU (OptiX)"
  $versionInfo = "7.6.0"
  $installFile = "NVIDIA-OptiX-SDK-$versionInfo-win64-31894579.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/OptiX/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/s /n" -Wait -RedirectStandardOutput "nvidia-optix.output.txt" -RedirectStandardError "nvidia-optix.error.txt"
  $sdkDirectory = "C:\ProgramData\NVIDIA Corporation\OptiX SDK $versionInfo\SDK"
  $buildDirectory = "$sdkDirectory\build"
  New-Item -ItemType Directory $buildDirectory
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$buildDirectory"" -S ""$sdkDirectory""" -Wait -RedirectStandardOutput "nvidia-optix-cmake.output.txt" -RedirectStandardError "nvidia-optix-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$buildDirectory\OptiX-Samples.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "nvidia-optix-msbuild.output.txt" -RedirectStandardError "nvidia-optix-msbuild.error.txt"
  $binPaths += ";$buildDirectory\bin\Release"
  Write-Host "Customize (End): NVIDIA GPU (OptiX)"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installFile = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installFile /quiet /norestart" -Wait
  Write-Host "Customize (End): Azure CLI"

  if ($renderManager -eq "Deadline") {
    Write-Host "Customize (Start): NFS Server"
    Install-WindowsFeature -Name "FS-NFS-Service"
    Write-Host "Customize (End): NFS Server"

    Write-Host "Customize (Start): NFS Client"
    Install-WindowsFeature -Name "NFS-Client"
    Write-Host "Customize (End): NFS Client"
  }
} else {
  Write-Host "Customize (Start): NFS Client"
  Start-Process -FilePath "dism.exe" -ArgumentList "/Enable-Feature /FeatureName:ClientForNFS-Infrastructure /Online /All /NoRestart" -Wait -RedirectStandardOutput "nfs-client.output.txt" -RedirectStandardError "nfs-client.error.txt"
  Write-Host "Customize (End): NFS Client"
}

switch ($renderManager) {
  "RoyalRender" {
    $schedulerVersion = "8.4.02"
  }
  "Deadline" {
    $schedulerVersion = "10.2.0.9"
    $schedulerClientPath = "C:\DeadlineClient"
    $schedulerDatabasePath = "C:\DeadlineDatabase"
    $schedulerRepositoryPath = "C:\DeadlineRepository"
    $schedulerCertificateFile = "Deadline10Client.pfx"
    $schedulerRepositoryLocalMount = "S:\"
    $schedulerRepositoryCertificate = "$schedulerRepositoryLocalMount$schedulerCertificateFile"
    $schedulerClientBinPath = "$schedulerClientPath\bin"
  }
}
$binPaths += ";$schedulerClientBinPath"

$rendererPathBlender = "C:\Program Files\Blender Foundation\Blender3"
$rendererPathPBRT3 = "C:\Program Files\PBRT\v3"
$rendererPathPBRT4 = "C:\Program Files\PBRT\v4"
$rendererPathUnreal = "C:\Program Files\Epic Games\Unreal5"
$rendererPathUnrealEditor = "$rendererPathUnreal\Engine\Binaries\Win64"

if ($renderEngines -contains "Blender") {
  $binPaths += ";$rendererPathBlender"
}
if ($renderEngines -contains "Unreal") {
  $binPaths += ";$rendererPathUnreal"
}
setx PATH "$env:PATH$binPaths" /m

switch ($renderManager) {
  "RoyalRender" {
    Write-Host "Customize (Start): Royal Render Download"
    $installFile = "RoyalRender__${schedulerVersion}__installer.zip"
    $downloadUrl = "$storageContainerUrl/RoyalRender/$schedulerVersion/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Expand-Archive -Path $installFile
    Write-Host "Customize (End): Royal Render Download"

    Write-Host "Customize (Start): Royal Render Installer"
    $rootDirectory = "RoyalRender"
    $installFile = "rrSetup_win.exe"
    $installDirectory = "RoyalRender__${schedulerVersion}__installer"
    New-Item -ItemType Directory -Path $rootDirectory
    Start-Process -FilePath .\$installDirectory\$installDirectory\$installFile -ArgumentList "-console -rrRoot $rootDirectory" -Wait -RedirectStandardOutput "$rootDirectory.output.txt" -RedirectStandardError "$rootDirectory.error.txt"
    Write-Host "Customize (End): Royal Render Installer"

    Set-Location -Path $rootDirectory
    if ($machineType -eq "Scheduler") {
      Write-Host "Customize (Start): Royal Render Server"

      Write-Host "Customize (End): Royal Render Server"
    }

    Write-Host "Customize (Start): Royal Render Client"

    Write-Host "Customize (End): Royal Render Client"
    Set-Location -Path $binDirectory
  }
  "Deadline" {
    Write-Host "Customize (Start): Deadline Download"
    $installFile = "Deadline-$schedulerVersion-windows-installers.zip"
    $downloadUrl = "$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Expand-Archive -Path $installFile
    Write-Host "Customize (End): Deadline Download"

    Set-Location -Path "Deadline*"
    if ($machineType -eq "Scheduler") {
      Write-Host "Customize (Start): Deadline Repository"
      netsh advfirewall firewall add rule name="Allow Mongo Database" dir=in action=allow protocol=TCP localport=27100
      $installFile = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
      Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --mongodir $schedulerDatabasePath --prefix $schedulerRepositoryPath" -Wait -RedirectStandardOutput "deadline-repository.output.txt" -RedirectStandardError "deadline-repository.error.txt"
      Move-Item -Path $env:TMP\*_installer.log -Destination .\deadline-log-repository.txt
      Copy-Item -Path $schedulerDatabasePath\certs\$schedulerCertificateFile -Destination $schedulerRepositoryPath\$schedulerCertificateFile
      New-NfsShare -Name "DeadlineRepository" -Path $schedulerRepositoryPath -Permission ReadWrite
      Write-Host "Customize (End): Deadline Repository"
    }

    Write-Host "Customize (Start): Deadline Client"
    netsh advfirewall firewall add rule name="Allow Deadline Worker" dir=in action=allow program="$schedulerClientBinPath\deadlineworker.exe"
    netsh advfirewall firewall add rule name="Allow Deadline Monitor" dir=in action=allow program="$schedulerClientBinPath\deadlinemonitor.exe"
    netsh advfirewall firewall add rule name="Allow Deadline Launcher" dir=in action=allow program="$schedulerClientBinPath\deadlinelauncher.exe"
    $installFile = "DeadlineClient-$schedulerVersion-windows-installer.exe"
    $installArgs = "--mode unattended --prefix $schedulerClientPath"
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
    Move-Item -Path $env:TMP\*_installer.log -Destination .\deadline-log-client.txt
    Start-Process -FilePath "$schedulerClientBinPath\deadlinecommand.exe" -ArgumentList "-ChangeRepositorySkipValidation Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate ''" -Wait -RedirectStandardOutput "deadline-change-repository.output.txt" -RedirectStandardError "deadline-change-repository.error.txt"
    Set-Location -Path $binDirectory
    Write-Host "Customize (End): Deadline Client"

    Write-Host "Customize (Start): Deadline Monitor Shortcut"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = $schedulerClientBinPath
    $shortcut.TargetPath = "$schedulerClientBinPath\deadlinemonitor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Deadline Monitor Shortcut"
  }
}

if ($renderEngines -contains "Blender") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.3.1"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" /quiet /norestart') -Wait -RedirectStandardOutput "blender.output.txt" -RedirectStandardError "blender.error.txt"
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
  Write-Host "Customize (Start): PBRT Data (Moana Island)"
  $dataDirectory = "moana"
  New-Item -ItemType Directory -Path $dataDirectory
  $installFile = "island-basepackage-v1.1.tgz"
  $downloadUrl = "$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  tar -xzf $installFile -C $dataDirectory
  $installFile = "island-pbrt-v1.1.tgz"
  $downloadUrl = "$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  tar -xzf $installFile -C $dataDirectory
  $installFile = "island-pbrtV4-v2.0.tgz"
  $downloadUrl = "$storageContainerUrl/PBRT/$dataDirectory/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  tar -xzf $installFile -C $dataDirectory
  Write-Host "Customize (End): PBRT Data (Moana Island)"
}

if ($renderEngines -contains "Unity") {
  Write-Host "Customize (Start): Unity"
  $installFile = "UnityHubSetup.exe"
  $downloadUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/$installFile"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S" -Wait -RedirectStandardOutput "unity-hub.output.txt" -RedirectStandardError "unity-hub.error.txt"
  Write-Host "Customize (End): Unity"
}

if ($renderEngines -contains "Unreal" -or $renderEngines -contains "Unreal.PixelStream") {
  Write-Host "Customize (Start): Unreal Engine"
  Start-Process -FilePath "dism.exe" -ArgumentList "/Enable-Feature /FeatureName:NetFX3 /Online /All /NoRestart" -Wait -RedirectStandardOutput "net-fx3.output.txt" -RedirectStandardError "net-fx3.error.txt"
  Set-Location -Path C:\
  $versionInfo = "5.1.0"
  $installFile = "UnrealEngine-$versionInfo-release.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  New-Item -ItemType Directory -Path "$rendererPathUnreal"
  Move-Item -Path "Unreal*\Unreal*\*" -Destination "$rendererPathUnreal"
  Remove-Item -Path "Unreal*" -Exclude "*.zip" -Recurse
  Set-Location -Path $binDirectory
  $installFile = "$rendererPathUnreal\Setup.bat"
  $scriptFilePath = $installFile
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("/register", "/register /unattended")
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText
  Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "unreal-engine.output.txt" -RedirectStandardError "unreal-engine.error.txt"
  Write-Host "Customize (End): Unreal Engine"

  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Visual Studio (Community Edition)"
    $versionInfo = "2022"
    $installFile = "VisualStudioSetup.exe"
    $downloadUrl = "$storageContainerUrl/VS/$versionInfo/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    # $componentIds = "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
    # $componentIds += " --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
    # $componentIds += " --add Microsoft.VisualStudio.Component.VSSDK"
    # $componentIds += " --add Microsoft.NetCore.Component.SDK"
    # $componentIds += " --add Microsoft.Net.Component.4.8.SDK"
    # Start-Process -FilePath .\$installFile -ArgumentList "$componentIds --quiet --norestart" -Wait -RedirectStandardOutput "vs.output.txt" -RedirectStandardError "vs.error.txt"
    # [System.Environment]::SetEnvironmentVariable("MSBuildSDKsPath", "C:\Program Files\dotnet\sdk\7.0.100\Sdks", [System.EnvironmentVariableTarget]::Machine)
    # [System.Environment]::SetEnvironmentVariable("MSBuildEnableWorkloadResolver", "false", [System.EnvironmentVariableTarget]::Machine)
    # $binPathDotNet = "C:\Program Files\dotnet"
    Write-Host "Customize (End): Visual Studio (Community Edition)"

    Write-Host "Customize (Start): Unreal Project Files"
    $installFile = "$rendererPathUnreal\GenerateProjectFiles.bat"
    $scriptFilePath = $installFile
    $scriptFileText = Get-Content -Path $scriptFilePath
    $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
    Set-Content -Path $scriptFilePath -Value $scriptFileText
    $scriptFilePath = "$rendererPathUnreal\Engine\Build\BatchFiles\GenerateProjectFiles.bat"
    $scriptFileText = Get-Content -Path $scriptFilePath
    $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
    Set-Content -Path $scriptFilePath -Value $scriptFileText
    # Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "unreal-files-generate.output.txt" -RedirectStandardError "unreal-files-generate.error.txt"
    # Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathUnreal\UE5.sln"" -p:Configuration=""Development Editor"" -p:Platform=Win64 -restore" -Wait -RedirectStandardOutput "unreal-files-build.output.txt" -RedirectStandardError "unreal-files-build.error.txt"
    # Start-Process -FilePath "$binPathDotNet\dotnet.exe" -ArgumentList "build ""$rendererPathUnreal\UE5.sln"" -c ""Development Editor""" -Wait -RedirectStandardOutput "unreal-files-build.output.txt" -RedirectStandardError "unreal-files-build.error.txt"
    Write-Host "Customize (End): Unreal Project Files"

    # Write-Host "Customize (Start): Unreal Editor"
    # netsh advfirewall firewall add rule name="Allow Unreal Editor" dir=in action=allow program="$rendererPathUnrealEditor\UnrealEditor.exe"
    # $shortcutPath = "$env:AllUsersProfile\Desktop\Unreal Editor.lnk"
    # $scriptShell = New-Object -ComObject WScript.Shell
    # $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    # $shortcut.WorkingDirectory = "$rendererPathUnrealEditor"
    # $shortcut.TargetPath = "$rendererPathUnrealEditor\UnrealEditor.exe"
    # $shortcut.Save()
    # Write-Host "Customize (End): Unreal Editor"
  }

  # if ($renderEngines -contains "Unreal.PixelStream") {
  #   Write-Host "Customize (Start): Unreal Pixel Streaming"
  #   Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/EpicGames/PixelStreamingInfrastructure" -Wait -RedirectStandardOutput "unreal-stream-git.output.txt" -RedirectStandardError "unreal-stream-git.error.txt"
  #   $installFile = "PixelStreamingInfrastructure\SignallingWebServer\platform_scripts\cmd\setup.bat"
  #   Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "unreal-stream-signalling.output.txt" -RedirectStandardError "unreal-stream-signalling.error.txt"
  #   $installFile = "PixelStreamingInfrastructure\Matchmaker\platform_scripts\cmd\setup.bat"
  #   Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "unreal-stream-matchmaker.output.txt" -RedirectStandardError "unreal-stream-matchmaker.error.txt"
  #   Write-Host "Customize (End): Unreal Pixel Streaming"
  # }
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
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S /NoPostReboot /Force" -Wait -RedirectStandardOutput "pcopi-agent.output.txt" -RedirectStandardError "pcoip-agent.error.txt"
  Write-Host "Customize (End): Teradici PCoIP"
}
