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

Write-Host "Customize (Start): Python"
$versionInfo = "3.7.9"
$installFile = "python-$versionInfo-amd64.exe"
$downloadUrl = "https://www.python.org/ftp/python/$versionInfo/$installFile"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
Start-Process -FilePath .\$installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /log python.txt" -Wait
Write-Host "Customize (End): Python"

Write-Host "Customize (Start): Git"
$versionInfo = "2.38.1"
$installFile = "Git-$versionInfo-64-bit.exe"
$downloadUrl = "$storageContainerUrl/Git/$versionInfo/$installFile$storageContainerSas"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
Start-Process -FilePath .\$installFile -ArgumentList "/silent /norestart /log=git.txt" -Wait
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
$binPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\MSBuild\Current\Bin\amd64"
$binPaths += ";$binPathCMake;$binPathMSBuild"
Write-Host "Customize (End): Visual Studio Build Tools"

Write-Host "Customize (Start): Image Build Parameters"
$buildConfigBytes = [System.Convert]::FromBase64String($buildConfigEncoded)
$buildConfig = [System.Text.Encoding]::UTF8.GetString($buildConfigBytes) | ConvertFrom-Json
$machineType = $buildConfig.machineType
$gpuPlatform = $buildConfig.gpuPlatform
$renderManager = $buildConfig.renderManager
$renderEngines = $buildConfig.renderEngines
$servicePassword = $buildConfig.servicePassword
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
  Start-Process -FilePath .\$installFile -ArgumentList "-s -n -log:$binDirectory\nvidia-gpu-grid" -Wait
  Write-Host "Customize (End): NVIDIA GPU (GRID)"
} elseif ($gpuPlatform -contains "AMD") {
  Write-Host "Customize (Start): AMD GPU"
  $installFile = "amd-gpu.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S" -Wait
  Start-Process -FilePath "C:\AMD\AMD*\Setup.exe" -ArgumentList "-install -log $binDirectory\amd-gpu.txt" -Wait
  Write-Host "Customize (End): AMD GPU"
}

if ($gpuPlatform -contains "CUDA" -or $gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA GPU (CUDA)"
  $versionInfo = "12.0.0"
  $installFile = "cuda_${versionInfo}_527.41_windows.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/CUDA/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "-s -n -log:$binDirectory\nvidia-gpu-cuda" -Wait
  Write-Host "Customize (End): NVIDIA GPU (CUDA)"
}

if ($gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA OptiX"
  $versionInfo = "7.6.0"
  $installFile = "NVIDIA-OptiX-SDK-$versionInfo-win64-31894579.exe"
  $downloadUrl = "$storageContainerUrl/NVIDIA/OptiX/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S /O $binDirectory\nvidia-optix.txt" -Wait
  $versionInfo = "v12.0"
  $sdkDirectory = "C:\ProgramData\NVIDIA Corporation\OptiX SDK $versionInfo\SDK"
  $buildDirectory = "$sdkDirectory\build"
  New-Item -ItemType Directory $buildDirectory
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$buildDirectory"" -S ""$sdkDirectory"" -D CUDA_TOOLKIT_ROOT_DIR=""C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\$versionInfo""" -Wait -RedirectStandardOutput "nvidia-optix-cmake.output.txt" -RedirectStandardError "nvidia-optix-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$buildDirectory\OptiX-Samples.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "nvidia-optix-msbuild.output.txt" -RedirectStandardError "nvidia-optix-msbuild.error.txt"
  $binPaths += ";$buildDirectory\bin\Release"
  Write-Host "Customize (End): NVIDIA OptiX"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installFile = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath $installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /norestart /log az-cli.txt" -Wait
  Write-Host "Customize (End): Azure CLI"

  if ($renderManager -like "*Deadline*") {
    Write-Host "Customize (Start): NFS Server"
    Install-WindowsFeature -Name "FS-NFS-Service"
    Write-Host "Customize (End): NFS Server"
  }
} else {
  Write-Host "Customize (Start): NFS Client"
  Start-Process -FilePath "dism.exe" -ArgumentList "/Enable-Feature /FeatureName:ClientForNFS-Infrastructure /Online /All /NoRestart" -Wait -RedirectStandardOutput "nfs-client.output.txt" -RedirectStandardError "nfs-client.error.txt"
  Write-Host "Customize (End): NFS Client"
}

if ($renderManager -like "*Deadline*") {
  $schedulerVersion = "10.2.1.0"
  $schedulerInstallRoot = "C:\Deadline"
  $schedulerClientMount = "S:\"
  $schedulerDatabaseHost = $(hostname)
  $schedulerDatabasePath = "C:\DeadlineDatabase"
  $schedulerCertificateFile = "Deadline10Client.pfx"
  $schedulerCertificate = "$schedulerClientMount$schedulerCertificateFile"
  $schedulerBinPath = "$schedulerInstallRoot\bin"
  $binPaths += ";$schedulerBinPath"

  Write-Host "Customize (Start): Deadline Download"
  $installFile = "Deadline-$schedulerVersion-windows-installers.zip"
  $downloadUrl = "$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Deadline Download"

  Set-Location -Path "Deadline*"
  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Deadline Server"
    netsh advfirewall firewall add rule name="Allow Deadline Database" dir=in action=allow protocol=TCP localport=27100
    $installFile = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
    Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --dbhost $schedulerDatabaseHost --mongodir $schedulerDatabasePath --prefix $schedulerInstallRoot" -Wait -RedirectStandardOutput "deadline-repository.output.txt" -RedirectStandardError "deadline-repository.error.txt"
    Move-Item -Path $env:TMP\*_installer.log -Destination .\deadline-log-repository.txt
    Copy-Item -Path $schedulerDatabasePath\certs\$schedulerCertificateFile -Destination $schedulerInstallRoot\$schedulerCertificateFile
    New-NfsShare -Name "Deadline" -Path $schedulerInstallRoot -Permission ReadWrite
    Write-Host "Customize (End): Deadline Server"
  } else {
    Write-Host "Customize (Start): Deadline Client"
    netsh advfirewall firewall add rule name="Allow Deadline Worker" dir=in action=allow program="$schedulerBinPath\deadlineworker.exe"
    netsh advfirewall firewall add rule name="Allow Deadline Monitor" dir=in action=allow program="$schedulerBinPath\deadlinemonitor.exe"
    netsh advfirewall firewall add rule name="Allow Deadline Launcher" dir=in action=allow program="$schedulerBinPath\deadlinelauncher.exe"
    $installFile = "DeadlineClient-$schedulerVersion-windows-installer.exe"
    $installArgs = "--mode unattended --prefix $schedulerInstallRoot"
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
    Start-Process -FilePath "$schedulerBinPath\deadlinecommand.exe" -ArgumentList "-ChangeRepositorySkipValidation Direct $schedulerClientMount $schedulerCertificate ''" -Wait -RedirectStandardOutput "deadline-change-repository.output.txt" -RedirectStandardError "deadline-change-repository.error.txt"
    Set-Location -Path $binDirectory
    Write-Host "Customize (End): Deadline Client"

    Write-Host "Customize (Start): Deadline Monitor"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = $schedulerBinPath
    $shortcut.TargetPath = "$schedulerBinPath\deadlinemonitor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Deadline Monitor"
  }
}

if ($renderManager -like "*RoyalRender*") {
  $schedulerVersion = "9.0.04"
  $schedulerInstallRoot = "\RoyalRender"
  $schedulerBinPath = "C:$schedulerInstallRoot\bin\win64"
  $binPaths += ";$schedulerBinPath"

  Write-Host "Customize (Start): Royal Render Download"
  $installFile = "RoyalRender__${schedulerVersion}__installer.zip"
  $downloadUrl = "$storageContainerUrl/RoyalRender/$schedulerVersion/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Royal Render Download"

  Write-Host "Customize (Start): Royal Render Installer"
  $installType = "royal-render"
  $installFile = "rrSetup_win.exe"
  $installDirectory = "RoyalRender*"
  New-Item -ItemType Directory -Path $schedulerInstallRoot
  New-SmbShare -Name "RoyalRender" -Path "C:$schedulerInstallRoot" -FullAccess "Everyone"
  Start-Process -FilePath .\$installDirectory\$installDirectory\$installFile -ArgumentList "-console -rrRoot \\$(hostname)$schedulerInstallRoot" -Wait -RedirectStandardOutput "$installType.output.txt" -RedirectStandardError "$installType.error.txt"
  Write-Host "Customize (End): Royal Render Installer"

  $serviceUser = "rrService"
  $securePassword = ConvertTo-SecureString $servicePassword -AsPlainText -Force
  $installFile = "rrWorkstation_installer.exe"
  New-LocalUser -Name $serviceUser -Password $securePassword -PasswordNeverExpires
  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Royal Render Server"
    Start-Process -FilePath $schedulerBinPath\$installFile -ArgumentList "-serviceServer -rrUser $serviceUser -rrUserPW $servicePassword -fwIn" -Wait -RedirectStandardOutput "$installType-server.output.txt" -RedirectStandardError "$installType-server.error.txt"
    Write-Host "Customize (End): Royal Render Server"
  } else {
    Write-Host "Customize (Start): Royal Render Client"
    Start-Process -FilePath $schedulerBinPath\$installFile -ArgumentList "-service -rrUser $serviceUser -rrUserPW $servicePassword -fwOut" -Wait -RedirectStandardOutput "$installType-client.output.txt" -RedirectStandardError "$installType-client.error.txt"
    Write-Host "Customize (End): Royal Render Client"

    Write-Host "Customize (Start): Royal Render Viewer"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Royal Render Viewer.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = $schedulerBinPath
    $shortcut.TargetPath = "$schedulerBinPath\rrViewer.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Royal Render Viewer"
  }
}

if ($renderManager -like "*Qube*") {
  $schedulerVersion = "7.5-2"
  $schedulerConfigFile = "C:\ProgramData\pfx\qube\qb.conf"
  $schedulerInstallRoot = "C:\Program Files\pfx\qube"
  $schedulerBinPath = "$schedulerInstallRoot\bin"
  $binPaths += ";$schedulerBinPath;$schedulerInstallRoot\sbin"

  Write-Host "Customize (Start): Qube Core"
  $installType = "qube-core"
  $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
  $downloadUrl = "$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath $installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /norestart /log $installType.txt" -Wait
  Write-Host "Customize (End): Qube Core"

  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Qube Supervisor"
    netsh advfirewall firewall add rule name="Allow Qube Database" dir=in action=allow protocol=TCP localport=50055
    netsh advfirewall firewall add rule name="Allow Qube Supervisor (TCP)" dir=in action=allow protocol=TCP localport=50001,50002
    netsh advfirewall firewall add rule name="Allow Qube Supervisor (UDP)" dir=in action=allow protocol=UDP localport=50001,50002
    netsh advfirewall firewall add rule name="Allow Qube Supervisor Proxy" dir=in action=allow protocol=TCP localport=50555,50556
    $installType = "qube-supervisor"
    $installFile = "$installType-${schedulerVersion}a-WIN32-6.3-x64.msi"
    $downloadUrl = "$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /norestart /log $installType.txt" -Wait
    $binPaths += ";C:\Program Files\pfx\pgsql\bin"
    Write-Host "Customize (End): Qube Supervisor"

    Write-Host "Customize (Start): Qube Data Relay Agent (DRA)"
    netsh advfirewall firewall add rule name="Allow Qube Data Relay Agent (DRA)" dir=in action=allow protocol=TCP localport=5001
    $installType = "qube-dra"
    $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
    $downloadUrl = "$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /norestart /log $installType.txt" -Wait
    Write-Host "Customize (End): Qube Data Relay Agent (DRA)"
  } else {
    Write-Host "Customize (Start): Qube Worker"
    netsh advfirewall firewall add rule name="Allow Qube Worker (TCP)" dir=in action=allow protocol=TCP localport=50011
    netsh advfirewall firewall add rule name="Allow Qube Worker (UDP)" dir=in action=allow protocol=UDP localport=50011
    $installType = "qube-worker"
    $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
    $downloadUrl = "$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /norestart /log $installType.txt" -Wait
    Write-Host "Customize (End): Qube Worker"

    Write-Host "Customize (Start): Qube Client"
    $installType = "qube-client"
    $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
    $downloadUrl = "$storageContainerUrl/Qube/$schedulerVersion/$installFile$storageContainerSas"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "InstallAllUsers=1 PrependPath=1 /quiet /norestart /log $installType.txt" -Wait
    $shortcutPath = "$env:AllUsersProfile\Desktop\Qube Client.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$schedulerInstallRoot\QubeUI"
    $shortcut.TargetPath = "$schedulerInstallRoot\QubeUI\QubeUI.bat"
    $shortcut.IconLocation = "$schedulerInstallRoot\lib\install\qube_icon.ico"
    $shortcut.Save()
    Write-Host "Customize (End): Qube Client"

    $configFileText = Get-Content -Path $schedulerConfigFile
    $configFileText = $configFileText.Replace("#qb_supervisor =", "qb_supervisor = render.artist.studio")
    $configFileText = $configFileText.Replace("#worker_cpus = 0", "worker_cpus = 1")
    Set-Content -Path $schedulerConfigFile -Value $configFileText
  }
}

$rendererPathPBRT = "C:\Program Files\PBRT"
$rendererPathBlender = "C:\Program Files\Blender"
$rendererPathUnreal = "C:\Program Files\Unreal"

if ($renderEngines -contains "PBRT") {
  $binPaths += ";$rendererPathPBRT"
}
if ($renderEngines -contains "Blender") {
  $binPaths += ";$rendererPathBlender"
}
if ($renderEngines -contains "Unreal") {
  $binPaths += ";$rendererPathUnreal"
}
setx PATH "$env:PATH$binPaths" /m

if ($renderEngines -contains "PBRT") {
  Write-Host "Customize (Start): PBRT 3"
  $versionInfo = "v3"
  $rendererPathPBRTv3 = "$rendererPathPBRT\$versionInfo"
  Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait -RedirectStandardOutput "pbrt-$versionInfo-git.output.txt" -RedirectStandardError "pbrt-$versionInfo-git.error.txt"
  New-Item -ItemType Directory -Path "$rendererPathPBRTv3" -Force
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$rendererPathPBRTv3"" -S $binDirectory\pbrt-$versionInfo" -Wait -RedirectStandardOutput "pbrt-$versionInfo-cmake.output.txt" -RedirectStandardError "pbrt-$versionInfo-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRTv3\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "pbrt-$versionInfo-msbuild.output.txt" -RedirectStandardError "pbrt-$versionInfo-msbuild.error.txt"
  New-Item -ItemType SymbolicLink -Target "$rendererPathPBRTv3\Release\pbrt.exe" -Path "$rendererPathPBRT\pbrt3"
  Write-Host "Customize (End): PBRT 3"

  Write-Host "Customize (Start): PBRT 4"
  $versionInfo = "v4"
  $rendererPathPBRTv4 = "$rendererPathPBRT\$versionInfo"
  Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait -RedirectStandardOutput "pbrt-$versionInfo-git.output.txt" -RedirectStandardError "pbrt-$versionInfo-git.error.txt"
  New-Item -ItemType Directory -Path "$rendererPathPBRTv4" -Force
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$rendererPathPBRTv4"" -S $binDirectory\pbrt-$versionInfo" -Wait -RedirectStandardOutput "pbrt-$versionInfo-cmake.output.txt" -RedirectStandardError "pbrt-$versionInfo-cmake.error.txt"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRTv4\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "pbrt-$versionInfo-msbuild.output.txt" -RedirectStandardError "pbrt-$versionInfo-msbuild.error.txt"
  New-Item -ItemType SymbolicLink -Target "$rendererPathPBRTv4\Release\pbrt.exe" -Path "$rendererPathPBRT\pbrt4"
  Write-Host "Customize (End): PBRT 4"
}

if ($renderEngines -contains "Blender") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.4.1"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" InstallAllUsers=1 PrependPath=1 /quiet /norestart /log blender.txt') -Wait
  $binPaths += ";$rendererPathBlender"
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -contains "Unreal" -or $renderEngines -contains "Unreal.PixelStream") {
  Write-Host "Customize (Start): Unreal Engine Setup"
  Start-Process -FilePath "dism.exe" -ArgumentList "/Enable-Feature /FeatureName:NetFX3 /Online /All /NoRestart" -Wait -RedirectStandardOutput "net-fx3.output.txt" -RedirectStandardError "net-fx3.error.txt"
  Set-Location -Path C:\
  $versionInfo = "5.1.1"
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
  Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "unreal-engine-setup.output.txt" -RedirectStandardError "unreal-engine-setup.error.txt"
  Write-Host "Customize (End): Unreal Engine Setup"

  Write-Host "Customize (Start): Visual Studio Workloads"
  $versionInfo = "2022"
  $installFile = "VisualStudioSetup.exe"
  $downloadUrl = "$storageContainerUrl/VS/$versionInfo/$installFile$storageContainerSas"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  $componentIds = "--add Microsoft.Net.Component.4.8.SDK"
  $componentIds += " --add Microsoft.Net.Component.4.6.2.TargetingPack"
  $componentIds += " --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
  $componentIds += " --add Microsoft.VisualStudio.Component.VSSDK"
  $componentIds += " --add Microsoft.VisualStudio.Workload.NativeGame"
  $componentIds += " --add Microsoft.VisualStudio.Workload.NativeDesktop"
  $componentIds += " --add Microsoft.VisualStudio.Workload.NativeCrossPlat"
  $componentIds += " --add Microsoft.VisualStudio.Workload.ManagedDesktop"
  $componentIds += " --add Microsoft.VisualStudio.Workload.Universal"
  Start-Process -FilePath .\$installFile -ArgumentList "$componentIds --quiet --norestart" -Wait -RedirectStandardOutput "vs.output.txt" -RedirectStandardError "vs.error.txt"
  Write-Host "Customize (End): Visual Studio Workloads"

  Write-Host "Customize (Start): Unreal Project Files Generate"
  $installFile = "$rendererPathUnreal\GenerateProjectFiles.bat"
  $scriptFilePath = $installFile
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText
  $scriptFilePath = "$rendererPathUnreal\Engine\Build\BatchFiles\GenerateProjectFiles.bat"
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText
  Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "unreal-project-files-generate.output.txt" -RedirectStandardError "unreal-project-files-generate.error.txt"
  Write-Host "Customize (End): Unreal Project Files Generate"

  Write-Host "Customize (Start): Unreal Engine Build"
  [System.Environment]::SetEnvironmentVariable("MSBuildEnableWorkloadResolver", "false")
  [System.Environment]::SetEnvironmentVariable("MSBuildSDKsPath", "$rendererPathUnreal\Engine\Binaries\ThirdParty\DotNet\6.0.302\windows\sdk\6.0.302\Sdks")
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathUnreal\UE5.sln"" -p:Configuration=""Development Client"" -p:Platform=Win64 -restore" -Wait -RedirectStandardOutput "unreal-engine-build.output.txt" -RedirectStandardError "unreal-engine-build.error.txt"
  Write-Host "Customize (End): Unreal Engine Build"

  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Unreal Editor"
    $rendererPathUnrealEditor = "$rendererPathUnreal\Engine\Binaries\Win64"
    netsh advfirewall firewall add rule name="Allow Unreal Editor" dir=in action=allow program="$rendererPathUnrealEditor\UnrealEditor.exe"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Unreal Editor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$rendererPathUnrealEditor"
    $shortcut.TargetPath = "$rendererPathUnrealEditor\UnrealEditor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Unreal Editor"
  }

  if ($renderEngines -contains "Unreal.PixelStream") {
    Write-Host "Customize (Start): Unreal Pixel Streaming"
    Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/EpicGames/PixelStreamingInfrastructure --branch UE5.1" -Wait -RedirectStandardOutput "unreal-stream-git.output.txt" -RedirectStandardError "unreal-stream-git.error.txt"
    $installFile = "PixelStreamingInfrastructure\SignallingWebServer\platform_scripts\cmd\setup.bat"
    Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "unreal-stream-signalling.output.txt" -RedirectStandardError "unreal-stream-signalling.error.txt"
    $installFile = "PixelStreamingInfrastructure\Matchmaker\platform_scripts\cmd\setup.bat"
    Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "unreal-stream-matchmaker.output.txt" -RedirectStandardError "unreal-stream-matchmaker.error.txt"
    $installFile = "PixelStreamingInfrastructure\SFU\platform_scripts\cmd\setup.bat"
    Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "unreal-stream-sfu.output.txt" -RedirectStandardError "unreal-stream-sfu.error.txt"
    Write-Host "Customize (End): Unreal Pixel Streaming"
  }
}

if ($renderEngines -contains "Unity") {
  Write-Host "Customize (Start): Unity Hub"
  $installFile = "UnityHubSetup.exe"
  $downloadUrl = "https://public-cdn.cloud.unity3d.com/hub/prod/$installFile"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S" -Wait -RedirectStandardOutput "unity-hub.output.txt" -RedirectStandardError "unity-hub.error.txt"
  Write-Host "Customize (End): Unity Hub"
}

if ($machineType -eq "Farm") {
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
  Start-Process -FilePath .\$installFile -ArgumentList "/S /NoPostReboot /Force" -Wait -RedirectStandardOutput "pcoip-agent.output.txt" -RedirectStandardError "pcoip-agent.error.txt"
  Write-Host "Customize (End): Teradici PCoIP"
}
