param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"

$binPaths = ""
$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

Write-Host "Customize (Start): Resize OS Disk"
$osDriveLetter = "C"
$partitionSizeActive = (Get-Partition -DriveLetter $osDriveLetter).Size
$partitionSizeRange = Get-PartitionSupportedSize -DriveLetter $osDriveLetter
if ($partitionSizeActive -lt $partitionSizeRange.SizeMax) {
  Resize-Partition -DriveLetter $osDriveLetter -Size $partitionSizeRange.SizeMax
}
Write-Host "Customize (End): Resize OS Disk"

Write-Host "Customize (Start): Image Build Parameters"
$buildConfigBytes = [System.Convert]::FromBase64String($buildConfigEncoded)
$buildConfig = [System.Text.Encoding]::UTF8.GetString($buildConfigBytes) | ConvertFrom-Json
$machineType = $buildConfig.machineType
$gpuPlatform = $buildConfig.gpuPlatform
$renderManager = $buildConfig.renderManager
$renderEngines = $buildConfig.renderEngines
$binStorageHost = $buildConfig.binStorageHost
$binStorageAuth = $buildConfig.binStorageAuth
Write-Host "Machine Type: $machineType"
Write-Host "GPU Platform: $gpuPlatform"
Write-Host "Render Manager: $renderManager"
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

Write-Host "Customize (Start): Chocolatey"
$installType = "chocolatey"
$installFile = "$installType.ps1"
$downloadUrl = "https://community.chocolatey.org/install.ps1"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File $installFile" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
$binPathChoco = "C:\ProgramData\chocolatey"
$binPaths += ";$binPathChoco"
Write-Host "Customize (End): Chocolatey"

Write-Host "Customize (Start): Python"
$installType = "python"
Start-Process -FilePath "$binPathChoco\choco" -ArgumentList "install $installType -y" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
Write-Host "Customize (End): Python"

Write-Host "Customize (Start): Git"
$installType = "git"
Start-Process -FilePath "$binPathChoco\choco" -ArgumentList "install $installType -y" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
$binPathGit = "C:\Program Files\Git\bin"
$binPaths += ";$binPathGit"
Write-Host "Customize (End): Git"

Write-Host "Customize (Start): Visual Studio Build Tools"
$versionInfo = "2022"
$installType = "vs-build-tools"
$installFile = "vs_BuildTools.exe"
$downloadUrl = "$binStorageHost/VS/$versionInfo/$installFile$binStorageAuth"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
$componentIds = "--add Microsoft.VisualStudio.Component.Windows11SDK.22621"
$componentIds += " --add Microsoft.VisualStudio.Component.VC.CMake.Project"
$componentIds += " --add Microsoft.Component.MSBuild"
Start-Process -FilePath .\$installFile -ArgumentList "$componentIds --quiet --norestart" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
$binPathCMake = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$binPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\MSBuild\Current\Bin\amd64"
$binPaths += ";$binPathCMake;$binPathMSBuild"
Write-Host "Customize (End): Visual Studio Build Tools"

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
  Start-Process -FilePath "C:\AMD\AMD*\Setup.exe" -ArgumentList "-install -log $binDirectory\amd-gpu.log" -Wait
  Write-Host "Customize (End): AMD GPU"
}

if ($gpuPlatform -contains "CUDA" -or $gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA GPU (CUDA)"
  $versionInfo = "12.1.0"
  $installFile = "cuda_${versionInfo}_531.14_windows.exe"
  $downloadUrl = "$binStorageHost/NVIDIA/CUDA/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "-s -n -log:$binDirectory\nvidia-gpu-cuda" -Wait
  Write-Host "Customize (End): NVIDIA GPU (CUDA)"
}

if ($gpuPlatform -contains "CUDA.OptiX") {
  Write-Host "Customize (Start): NVIDIA OptiX"
  $versionInfo = "7.7.0"
  $installType = "nvidia-optix"
  $installFile = "NVIDIA-OptiX-SDK-$versionInfo-win64-32649046.exe"
  $downloadUrl = "$binStorageHost/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S /O $binDirectory\nvidia-optix.log" -Wait
  $versionInfo = "v12.0"
  $sdkDirectory = "C:\ProgramData\NVIDIA Corporation\OptiX SDK $versionInfo\SDK"
  $buildDirectory = "$sdkDirectory\build"
  New-Item -ItemType Directory $buildDirectory
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$buildDirectory"" -S ""$sdkDirectory"" -D CUDA_TOOLKIT_ROOT_DIR=""C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\$versionInfo""" -Wait -RedirectStandardOutput "$installType-cmake.out.log" -RedirectStandardError "$installType-cmake.err.log"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$buildDirectory\OptiX-Samples.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "$installType-msbuild.out.log" -RedirectStandardError "$installType-msbuild.err.log"
  $binPaths += ";$buildDirectory\bin\Release"
  Write-Host "Customize (End): NVIDIA OptiX"
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installFile = "az-cli.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath $installFile -ArgumentList "/quiet /norestart /log az-cli.log" -Wait
  Write-Host "Customize (End): Azure CLI"

  if ("$renderManager" -like "*Deadline*" -or "$renderManager" -like "*RoyalRender*") {
    Write-Host "Customize (Start): NFS Server"
    Install-WindowsFeature -Name "FS-NFS-Service"
    Write-Host "Customize (End): NFS Server"
  }
} else {
  Write-Host "Customize (Start): NFS Client"
  $installType = "nfs-client"
  Start-Process -FilePath "dism.exe" -ArgumentList "/Enable-Feature /FeatureName:ClientForNFS-Infrastructure /Online /All /NoRestart" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  Write-Host "Customize (End): NFS Client"
}

if ("$renderManager" -like "*Deadline*") {
  $schedulerVersion = "10.2.1.0"
  $schedulerInstallRoot = "C:\Deadline"
  $schedulerDatabaseHost = $(hostname)
  $schedulerDatabasePath = "C:\DeadlineDatabase"
  $schedulerCertificateFile = "Deadline10Client.pfx"
  $schedulerBinPath = "$schedulerInstallRoot\bin"

  Write-Host "Customize (Start): Deadline Download"
  $installFile = "Deadline-$schedulerVersion-windows-installers.zip"
  $downloadUrl = "$binStorageHost/Deadline/$schedulerVersion/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Deadline Download"

  Set-Location -Path "Deadline*"
  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Deadline Server"
    netsh advfirewall firewall add rule name="Allow Deadline Database" dir=in action=allow protocol=TCP localport=27100
    $installType = "deadline-repository"
    $installFile = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
    Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --prefix $schedulerInstallRoot --dbhost $schedulerDatabaseHost --mongodir $schedulerDatabasePath --installmongodb true" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
    Copy-Item -Path $env:TMP\installbuilder_installer.log -Destination $binDirectory\deadline-repository.log
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
    Copy-Item -Path $env:TMP\installbuilder_installer.log -Destination $binDirectory\deadline-client.log
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

  $binPaths += ";$schedulerBinPath"
}

if ("$renderManager" -like "*RoyalRender*") {
  $schedulerVersion = "9.0.04"
  $schedulerInstallRoot = "\RoyalRender"
  $schedulerBinPath = "C:$schedulerInstallRoot\bin\win64"

  Write-Host "Customize (Start): Royal Render Download"
  $installFile = "RoyalRender__${schedulerVersion}__installer.zip"
  $downloadUrl = "$binStorageHost/RoyalRender/$schedulerVersion/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Royal Render Download"

  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Royal Render Server"
    $installType = "royal-render"
    $installPath = "RoyalRender*"
    $installFile = "rrSetup_win.exe"
    $rrShareName = $schedulerInstallRoot.TrimStart("\")
    $rrRootShare = "\\$(hostname)$schedulerInstallRoot"
    New-Item -ItemType Directory -Path $schedulerInstallRoot
    New-SmbShare -Name $rrShareName -Path "C:$schedulerInstallRoot" -FullAccess "Everyone"
    Start-Process -FilePath .\$installPath\$installPath\$installFile -ArgumentList "-console -rrRoot $rrRootShare" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
    Remove-SmbShare -Name $rrShareName -Force
    New-NfsShare -Name "RoyalRender" -Path C:$schedulerInstallRoot -Permission ReadWrite
    Write-Host "Customize (End): Royal Render Server"
  }

  Write-Host "Customize (Start): Royal Render Viewer"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Royal Render Viewer.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $schedulerBinPath
  $shortcut.TargetPath = "$schedulerBinPath\rrViewer.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Royal Render Viewer"

  $binPaths += ";$schedulerBinPath"
}

if ("$renderManager" -like "*Qube*") {
  $schedulerVersion = "8.0-0"
  $schedulerConfigFile = "C:\ProgramData\pfx\qube\qb.conf"
  $schedulerInstallRoot = "C:\Program Files\pfx\qube"
  $schedulerBinPath = "$schedulerInstallRoot\bin"

  Write-Host "Customize (Start): Strawberry Perl"
  $installType = "strawberryperl"
  Start-Process -FilePath "$binPathChoco\choco" -ArgumentList "install $installType -y" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  Write-Host "Customize (End): Strawberry Perl"

  Write-Host "Customize (Start): Qube Core"
  $installType = "qube-core"
  $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
  $downloadUrl = "$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath $installFile -ArgumentList "/quiet /norestart /log $installType.log" -Wait
  Write-Host "Customize (End): Qube Core"

  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Qube Supervisor"
    netsh advfirewall firewall add rule name="Allow Qube Database" dir=in action=allow protocol=TCP localport=50055
    netsh advfirewall firewall add rule name="Allow Qube Supervisor (TCP)" dir=in action=allow protocol=TCP localport=50001,50002
    netsh advfirewall firewall add rule name="Allow Qube Supervisor (UDP)" dir=in action=allow protocol=UDP localport=50001,50002
    netsh advfirewall firewall add rule name="Allow Qube Supervisor Proxy" dir=in action=allow protocol=TCP localport=50555,50556
    $installType = "qube-supervisor"
    $installFile = "$installType-${schedulerVersion}-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "/quiet /norestart /log $installType.log" -Wait
    $binPaths += ";C:\Program Files\pfx\pgsql\bin"
    Write-Host "Customize (End): Qube Supervisor"

    Write-Host "Customize (Start): Qube Data Relay Agent (DRA)"
    netsh advfirewall firewall add rule name="Allow Qube Data Relay Agent (DRA)" dir=in action=allow protocol=TCP localport=5001
    $installType = "qube-dra"
    $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "/quiet /norestart /log $installType.log" -Wait
    Write-Host "Customize (End): Qube Data Relay Agent (DRA)"
  } else {
    Write-Host "Customize (Start): Qube Worker"
    netsh advfirewall firewall add rule name="Allow Qube Worker (TCP)" dir=in action=allow protocol=TCP localport=50011
    netsh advfirewall firewall add rule name="Allow Qube Worker (UDP)" dir=in action=allow protocol=UDP localport=50011
    $installType = "qube-worker"
    $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "/quiet /norestart /log $installType.log" -Wait
    Write-Host "Customize (End): Qube Worker"

    Write-Host "Customize (Start): Qube Client"
    $installType = "qube-client"
    $installFile = "$installType-$schedulerVersion-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$schedulerVersion/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Start-Process -FilePath $installFile -ArgumentList "/quiet /norestart /log $installType.log" -Wait
    $shortcutPath = "$env:AllUsersProfile\Desktop\Qube Client.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$schedulerInstallRoot\QubeUI"
    $shortcut.TargetPath = "$schedulerInstallRoot\QubeUI\QubeUI.bat"
    $shortcut.IconLocation = "$schedulerInstallRoot\lib\install\qube_icon.ico"
    $shortcut.Save()
    Write-Host "Customize (End): Qube Client"

    $configFileText = Get-Content -Path $schedulerConfigFile
    $configFileText = $configFileText.Replace("#qb_supervisor =", "qb_supervisor = scheduler.content.studio")
    $configFileText = $configFileText.Replace("#worker_cpus = 0", "worker_cpus = 1")
    Set-Content -Path $schedulerConfigFile -Value $configFileText
  }

  $binPaths += ";$schedulerBinPath;$schedulerInstallRoot\sbin"
}

if ($renderEngines -contains "*Maya*") {
  Write-Host "Customize (Start): Maya"
  $versionInfo = "2024_0_1"
  $installFile = "Autodesk_Maya_${versionInfo}_Update_Windows_64bit_dlm.zip"
  $downloadUrl = "$binStorageHost/Maya/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Start-Process -FilePath .\Autodesk_Maya*\Autodesk_Maya*\Setup.exe -ArgumentList "--silent"
  Start-Sleep -Seconds 600
  $binPaths += ";C:\Program Files\Autodesk\Maya2024\bin"
  Write-Host "Customize (End): Maya"
}

if ($renderEngines -contains "PBRT") {
  Write-Host "Customize (Start): PBRT v3"
  $versionInfo = "v3"
  $installType = "pbrt-$versionInfo"
  $installPath = "C:\Program Files\PBRT"
  $installPathV3 = "$installPath\$versionInfo"
  Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/$installType.git" -Wait -RedirectStandardOutput "$installType-git.out.log" -RedirectStandardError "$installType-git.err.log"
  New-Item -ItemType Directory -Path "$installPathV3" -Force
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$installPathV3"" -S $binDirectory\$installType" -Wait -RedirectStandardOutput "$installType-cmake.out.log" -RedirectStandardError "$installType-cmake.err.log"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$installPathV3\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "$installType-msbuild.out.log" -RedirectStandardError "$installType-msbuild.err.log"
  New-Item -ItemType SymbolicLink -Target "$installPathV3\Release\pbrt.exe" -Path "$installPath\pbrt3"
  Write-Host "Customize (End): PBRT v3"

  Write-Host "Customize (Start): PBRT v4"
  $versionInfo = "v4"
  $installType = "pbrt-$versionInfo"
  $installPathV4 = "$installPath\$versionInfo"
  Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/$installType.git" -Wait -RedirectStandardOutput "$installType-git.out.log" -RedirectStandardError "$installType-git.err.log"
  New-Item -ItemType Directory -Path "$installPathV4" -Force
  Start-Process -FilePath "$binPathCMake\cmake.exe" -ArgumentList "-B ""$installPathV4"" -S $binDirectory\$installType" -Wait -RedirectStandardOutput "$installType-cmake.out.log" -RedirectStandardError "$installType-cmake.err.log"
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$installPathV4\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "$installType-msbuild.out.log" -RedirectStandardError "$installType-msbuild.err.log"
  New-Item -ItemType SymbolicLink -Target "$installPathV4\Release\pbrt.exe" -Path "$installPath\pbrt4"
  Write-Host "Customize (End): PBRT v4"

  $binPaths += ";$installPath"
}

if ($renderEngines -contains "Houdini") {
  Write-Host "Customize (Start): Houdini"
  $versionInfo = "19.5.569"
  $versionEULA = "2021-10-13"
  $installType = "houdini"
  $installFile = "$installType-$versionInfo-win64-vc142.exe"
  $downloadUrl = "$binStorageHost/Houdini/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  if ($machineType -eq "Workstation") {
    $installArgs = "/MainApp=Yes"
  } else {
    $installArgs = "/HoudiniEngineOnly=Yes"
  }
  if ($renderEngines -contains "Maya") {
    $installArgs += " /EngineMaya=Yes"
  }
  if ($renderEngines -contains "Unreal") {
    $installArgs += " /EngineUnreal=Yes"
  }
  Start-Process -FilePath .\$installFile -ArgumentList "/S /AcceptEULA=$versionEULA $installArgs" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  $binPaths += ";C:\Program Files\Side Effects Software\Houdini $versionInfo\bin"
  Write-Host "Customize (End): Houdini"
}

if ($renderEngines -contains "Blender") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.5.1"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$binStorageHost/Blender/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' /quiet /norestart /log blender.log') -Wait
  $binPaths += ";C:\Program Files\Blender Foundation\Blender 3.5"
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -contains "Unreal" -or $renderEngines -contains "Unreal+PixelStream") {
  Write-Host "Customize (Start): Visual Studio Workloads"
  $versionInfo = "2022"
  $installType = "unreal-vs"
  $installFile = "VisualStudioSetup.exe"
  $downloadUrl = "$binStorageHost/VS/$versionInfo/$installFile$binStorageAuth"
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
  Start-Process -FilePath .\$installFile -ArgumentList "$componentIds --quiet --norestart" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  Write-Host "Customize (End): Visual Studio Workloads"

  Write-Host "Customize (Start): Unreal Engine Setup"
  $installType = "net-fx3"
  Start-Process -FilePath "dism.exe" -ArgumentList "/Enable-Feature /FeatureName:NetFX3 /Online /All /NoRestart" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  Set-Location -Path C:\
  $versionInfo = "5.1.1"
  $installType = "unreal-engine"
  $installPath = "C:\Program Files\Unreal"
  $installFile = "UnrealEngine-$versionInfo-release.zip"
  $downloadUrl = "$binStorageHost/Unreal/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile

  New-Item -ItemType Directory -Path "$installPath"
  Move-Item -Path "Unreal*\Unreal*\*" -Destination "$installPath"
  Remove-Item -Path "Unreal*" -Exclude "*.zip" -Recurse
  Set-Location -Path $binDirectory
  $installFile = "$installPath\Setup.bat"
  $scriptFilePath = $installFile
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("/register", "/register /unattended")
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText
  Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "$installType-setup.out.log" -RedirectStandardError "$installType-setup.err.log"
  Write-Host "Customize (End): Unreal Engine Setup"

  Write-Host "Customize (Start): Unreal Project Files Generate"
  $installFile = "$installPath\GenerateProjectFiles.bat"
  $scriptFilePath = $installFile
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText
  $scriptFilePath = "$installPath\Engine\Build\BatchFiles\GenerateProjectFiles.bat"
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText
  Start-Process -FilePath "$installFile" -Wait -RedirectStandardOutput "unreal-project-files-generate.out.log" -RedirectStandardError "unreal-project-files-generate.err.log"
  Write-Host "Customize (End): Unreal Project Files Generate"

  Write-Host "Customize (Start): Unreal Engine Build"
  [System.Environment]::SetEnvironmentVariable("MSBuildEnableWorkloadResolver", "false")
  [System.Environment]::SetEnvironmentVariable("MSBuildSDKsPath", "$installPath\Engine\Binaries\ThirdParty\DotNet\6.0.302\windows\sdk\6.0.302\Sdks")
  Start-Process -FilePath "$binPathMSBuild\MSBuild.exe" -ArgumentList """$installPath\UE5.sln"" -p:Configuration=""Development Client"" -p:Platform=Win64 -restore" -Wait -RedirectStandardOutput "$installType-build.out.log" -RedirectStandardError "$installType-build.err.log"
  Write-Host "Customize (End): Unreal Engine Build"

  if ($renderEngines -contains "Unreal+PixelStream") {
    Write-Host "Customize (Start): Unreal Pixel Streaming"
    $installType = "unreal-stream"
    Start-Process -FilePath "$binPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/EpicGames/PixelStreamingInfrastructure --branch UE5.1" -Wait -RedirectStandardOutput "$installType-git.out.log" -RedirectStandardError "$installType-git.err.log"
    $installFile = "PixelStreamingInfrastructure\SignallingWebServer\platform_scripts\cmd\setup.bat"
    Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "$installType-signalling.out.log" -RedirectStandardError "$installType-signalling.err.log"
    $installFile = "PixelStreamingInfrastructure\Matchmaker\platform_scripts\cmd\setup.bat"
    Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "$installType-matchmaker.out.log" -RedirectStandardError "$installType-matchmaker.err.log"
    $installFile = "PixelStreamingInfrastructure\SFU\platform_scripts\cmd\setup.bat"
    Start-Process -FilePath .\$installFile -Wait -RedirectStandardOutput "$installType-sfu.out.log" -RedirectStandardError "$installType-sfu.err.log"
    Write-Host "Customize (End): Unreal Pixel Streaming"
  }

  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Unreal Editor"
    $installPathEditor = "$installPath\Engine\Binaries\Win64"
    netsh advfirewall firewall add rule name="Allow Unreal Editor" dir=in action=allow program="$installPathEditor\UnrealEditor.exe"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Unreal Editor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$installPathEditor"
    $shortcut.TargetPath = "$installPathEditor\UnrealEditor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Unreal Editor"
  }

  $binPaths += ";$installPath"
}

setx PATH "$env:PATH$binPaths" /m

if ($machineType -eq "Farm") {
  Write-Host "Customize (Start): Privacy Experience"
  $registryKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
  New-Item -ItemType Directory -Path $registryKeyPath -Force
  New-ItemProperty -Path $registryKeyPath -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force
  Write-Host "Customize (End): Privacy Experience"
}

if ($machineType -eq "Workstation") {
  Write-Host "Customize (Start): Teradici PCoIP"
  $versionInfo = "23.04.1"
  $installType = if ($gpuPlatform -contains "GRID") {"pcoip-agent-graphics"} else {"pcoip-agent-standard"}
  $installFile = "${installType}_$versionInfo.exe"
  $downloadUrl = "$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Start-Process -FilePath .\$installFile -ArgumentList "/S /NoPostReboot /Force" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  Write-Host "Customize (End): Teradici PCoIP"
}
