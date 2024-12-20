param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"

$binPaths = ""
$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

. "C:\AzureData\functions.ps1"

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
$gpuProvider = $buildConfig.gpuProvider
$renderEngines = $buildConfig.renderEngines
$binStorageHost = $buildConfig.binStorage.host
$binStorageAuth = $buildConfig.binStorage.auth
Write-Host "Machine Type: $machineType"
Write-Host "GPU Provider: $gpuProvider"
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

Write-Host "Customize (Start): Image Build Platform"
netsh advfirewall set allprofiles state off

Write-Host "Customize (Start): Chocolatey"
$installType = "chocolatey"
$installFile = "$installType.ps1"
$downloadUrl = "https://community.chocolatey.org/install.ps1"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
StartProcess PowerShell.exe "-ExecutionPolicy Unrestricted -File .\$installFile" "$binDirectory\$installType"
$binPathChoco = "C:\ProgramData\chocolatey"
$binPaths += ";$binPathChoco"
Write-Host "Customize (End): Chocolatey"

Write-Host "Customize (Start): Python"
$installType = "python"
StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" "$binDirectory\$installType"
Write-Host "Customize (End): Python"

if ($machineType -eq "Workstation") {
  Write-Host "Customize (Start): Node.js"
  $installType = "nodejs"
  StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" "$binDirectory\$installType"
  Write-Host "Customize (End): Node.js"
}

Write-Host "Customize (Start): Git"
$installType = "git"
StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" "$binDirectory\$installType"
$binPathGit = "C:\Program Files\Git\bin"
$binPaths += ";$binPathGit"
Write-Host "Customize (End): Git"

Write-Host "Customize (Start): 7-Zip"
$installType = "7zip"
StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" "$binDirectory\$installType"
Write-Host "Customize (End): 7-Zip"

Write-Host "Customize (Start): Visual Studio Build Tools"
$versionInfo = "2022"
$installType = "vs-build-tools"
$installFile = "vs_BuildTools.exe"
$downloadUrl = "$binStorageHost/VS/$versionInfo/$installFile$binStorageAuth"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
$componentIds = "--add Microsoft.VisualStudio.Component.Windows11SDK.22621"
$componentIds += " --add Microsoft.VisualStudio.Component.VC.CMake.Project"
$componentIds += " --add Microsoft.Component.MSBuild"
StartProcess .\$installFile "$componentIds --quiet --norestart" "$binDirectory\$installType"
$binPathCMake = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$binPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\MSBuild\Current\Bin\amd64"
$binPaths += ";$binPathCMake;$binPathMSBuild"
Write-Host "Customize (End): Visual Studio Build Tools"

Write-Host "Customize (End): Image Build Platform"

if ($gpuProvider -eq "AMD") {
  $installType = "amd-gpu"
  if ($machineType -like "*NG*" -and $machineType -like "*v1*") {
    Write-Host "Customize (Start): AMD GPU (NG v1)"
    $installFile = "$installType.exe"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2248541"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess .\$installFile "-install -log $binDirectory\$installType.log" $null
    Write-Host "Customize (End): AMD GPU (NG v1)"
  } elseif ($machineType -like "*NV*" -and $machineType -like "*v4*") {
    Write-Host "Customize (Start): AMD GPU (NV v4)"
    $installFile = "$installType.exe"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess .\$installFile "-install -log $binDirectory\$installType.log" $null
    Write-Host "Customize (End): AMD GPU (NV v4)"
  }
} elseif ($gpuProvider -eq "NVIDIA") {
  Write-Host "Customize (Start): NVIDIA GPU (GRID)"
  $installType = "nvidia-gpu-grid"
  $installFile = "$installType.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "-s -n -log:$binDirectory\$installType" $null
  Write-Host "Customize (End): NVIDIA GPU (GRID)"

  Write-Host "Customize (Start): NVIDIA GPU (CUDA)"
  $versionInfo = "12.2.2"
  $installType = "nvidia-gpu-cuda"
  $installFile = "cuda_${versionInfo}_windows_network.exe"
  $downloadUrl = "$binStorageHost/NVIDIA/CUDA/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "-s -n -log:$binDirectory\$installType" $null
  Write-Host "Customize (End): NVIDIA GPU (CUDA)"

  Write-Host "Customize (Start): NVIDIA OptiX"
  $versionInfo = "8.0.0"
  $installType = "nvidia-optix"
  $installFile = "NVIDIA-OptiX-SDK-$versionInfo-win64.exe"
  $downloadUrl = "$binStorageHost/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "/S" $null
  $sdkDirectory = "C:\ProgramData\NVIDIA Corporation\OptiX SDK $versionInfo\SDK"
  $buildDirectory = "$sdkDirectory\build"
  New-Item -ItemType Directory $buildDirectory
  $versionInfo = "v12.2"
  StartProcess $binPathCMake\cmake.exe "-B ""$buildDirectory"" -S ""$sdkDirectory"" -D CUDA_TOOLKIT_ROOT_DIR=""C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\$versionInfo""" "$binDirectory\$installType-cmake"
  StartProcess $binPathMSBuild\MSBuild.exe """$buildDirectory\OptiX-Samples.sln"" -p:Configuration=Release" "$binDirectory\$installType-msbuild"
  $binPaths += ";$buildDirectory\bin\Release"
  Write-Host "Customize (End): NVIDIA OptiX"
}

if ($machineType -eq "Storage" -or $machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI (x64)"
  $installType = "azure-cli"
  $installFile = "$installType.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindowsx64"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess $installFile "/quiet /norestart /log $installType.log" $null
  Write-Host "Customize (End): Azure CLI (x64)"
}

if ($renderEngines -contains "PBRT") {
  Write-Host "Customize (Start): PBRT"
  $versionInfo = "v4"
  $installType = "pbrt"
  $installPath = "C:\Program Files\PBRT"
  New-Item -ItemType Directory -Path $installPath -Force
  StartProcess $binPathGit\git.exe "clone --recursive https://github.com/mmp/$installType-$versionInfo.git" "$binDirectory\$installType-git"
  StartProcess $binPathCMake\cmake.exe "-B ""$installPath"" -S $binDirectory\$installType-$versionInfo" "$binDirectory\$installType-cmake"
  StartProcess $binPathMSBuild\MSBuild.exe """$installPath\PBRT-$versionInfo.sln"" -p:Configuration=Release" "$binDirectory\$installType-msbuild"
  $binPaths += ";$installPath\Release"
  Write-Host "Customize (End): PBRT"
}

if ($renderEngines -contains "Blender") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.6.4"
  $installType = "blender"
  $installFile = "$installType-$versionInfo-windows-x64.msi"
  $downloadUrl = "$binStorageHost/Blender/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess $installFile "/quiet /norestart /log $installType.log" $null
  $binPaths += ";C:\Program Files\Blender Foundation\Blender 3.6"
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -contains "RenderMan") {
  Write-Host "Customize (Start): RenderMan"
  $versionInfo = "25.2.0"
  $installType = "renderman"
  $installFile = "RenderMan-InstallerNCR-${versionInfo}_2282810-windows10_vc15icc216.x86_64.msi"
  $downloadUrl = "$binStorageHost/RenderMan/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess $installFile "/quiet /norestart /log $installType.log" $null
  Write-Host "Customize (End): RenderMan"
}

if ($renderEngines -contains "Maya") {
  Write-Host "Customize (Start): Maya"
  $versionInfo = "2024_0_1"
  $installType = "maya"
  $installFile = "Autodesk_Maya_${versionInfo}_Update_Windows_64bit_dlm.zip"
  $downloadUrl = "$binStorageHost/Maya/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Start-Process -FilePath .\Autodesk_Maya*\Autodesk_Maya*\Setup.exe -ArgumentList "--silent" -RedirectStandardOutput $installType-out -RedirectStandardError $installType-err
  Start-Sleep -Seconds 600
  $binPaths += ";C:\Program Files\Autodesk\Maya2024\bin"
  Write-Host "Customize (End): Maya"
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
  StartProcess .\$installFile "/S /AcceptEULA=$versionEULA $installArgs" "$binDirectory\$installType"
  $binPaths += ";C:\Program Files\Side Effects Software\Houdini $versionInfo\bin"
  Write-Host "Customize (End): Houdini"
}

if ($renderEngines -contains "Unreal" -or $renderEngines -contains "Unreal+PixelStream") {
  Write-Host "Customize (Start): Visual Studio Workloads"
  $versionInfo = "2022"
  $installType = "unreal-visual-studio"
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
  StartProcess .\$installFile "$componentIds --quiet --norestart" "$binDirectory\$installType"
  Write-Host "Customize (End): Visual Studio Workloads"

  Write-Host "Customize (Start): Unreal Engine Setup"
  $installType = "dotnet-fx3"
  StartProcess dism.exe "/Online /Enable-Feature /FeatureName:NetFX3 /All /NoRestart" "$binDirectory\$installType"
  Set-Location -Path C:\
  $versionInfo = "5.3.0"
  $installType = "unreal-engine"
  $installFile = "UnrealEngine-$versionInfo-release.zip"
  $downloadUrl = "$binStorageHost/Unreal/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile

  $installPath = "C:\Program Files\Unreal"
  New-Item -ItemType Directory -Path $installPath
  Move-Item -Path "Unreal*\Unreal*\*" -Destination $installPath
  Remove-Item -Path "Unreal*" -Exclude "*.zip" -Recurse
  Set-Location -Path $binDirectory

  $buildPath = $installPath.Replace("\", "\\")
  $buildPath = "$buildPath\\Engine\\Binaries\\ThirdParty\\Windows\\DirectX\\x64\"
  $scriptFilePath = "$installPath\Engine\Source\Programs\ShaderCompileWorker\ShaderCompileWorker.Build.cs"
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("DirectX.GetDllDir(Target) + ", "")
  $scriptFileText = $scriptFileText.Replace("d3dcompiler_47.dll", "$buildPath\d3dcompiler_47.dll")
  Set-Content -Path $scriptFilePath -Value $scriptFileText

  $installFile = "$installPath\Setup.bat"
  $scriptFilePath = $installFile
  $scriptFileText = Get-Content -Path $scriptFilePath
  $scriptFileText = $scriptFileText.Replace("/register", "/register /unattended")
  $scriptFileText = $scriptFileText.Replace("pause", "rem pause")
  Set-Content -Path $scriptFilePath -Value $scriptFileText

  StartProcess $installFile $null "$binDirectory\$installType-setup"
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
  StartProcess $installFile $null "$binDirectory\unreal-project-files-generate"
  Write-Host "Customize (End): Unreal Project Files Generate"

  Write-Host "Customize (Start): Unreal Engine Build"
  [System.Environment]::SetEnvironmentVariable("MSBuildEnableWorkloadResolver", "false")
  [System.Environment]::SetEnvironmentVariable("MSBuildSDKsPath", "$installPath\Engine\Binaries\ThirdParty\DotNet\6.0.302\windows\sdk\6.0.302\Sdks")
  StartProcess $binPathMSBuild\MSBuild.exe """$installPath\UE5.sln"" -p:Configuration=""Development Editor"" -p:Platform=Win64 -restore" "$binDirectory\$installType-msbuild"
  Write-Host "Customize (End): Unreal Engine Build"

  if ($renderEngines -contains "Unreal+PixelStream") {
    Write-Host "Customize (Start): Unreal Pixel Streaming"
    $versionInfo = "5.3-0.0.3"
    $installType = "unreal-stream"
    $installFile = "UE$versionInfo.zip"
    $downloadUrl = "$binStorageHost/Unreal/PixelStream/$versionInfo/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Expand-Archive -Path $installFile
    $installFile = "UE$versionInfo\PixelStreamingInfrastructure-UE$versionInfo\SignallingWebServer\platform_scripts\cmd\setup.bat"
    StartProcess .\$installFile $null "$binDirectory\$installType-signalling"
    $installFile = "UE$versionInfo\PixelStreamingInfrastructure-UE$versionInfo\Matchmaker\platform_scripts\cmd\setup.bat"
    StartProcess .\$installFile $null "$binDirectory\$installType-matchmaker"
    $installFile = "UE$versionInfo\PixelStreamingInfrastructure-UE$versionInfo\SFU\platform_scripts\cmd\setup.bat"
    StartProcess .\$installFile $null "$binDirectory\$installType-sfu"
    Write-Host "Customize (End): Unreal Pixel Streaming"
  }

  $binPathUnreal = "$installPath\Engine\Binaries\Win64"
  $binPaths += ";$binPathUnreal"

  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Unreal Editor"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Unreal Editor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$binPathUnreal"
    $shortcut.TargetPath = "$binPathUnreal\UnrealEditor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Unreal Editor"
  }
}

if ($machineType -eq "Scheduler") {
  Write-Host "Customize (Start): AD Domain Services"
  Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools
  Write-Host "Customize (End): AD Domain Services"

  Write-Host "Customize (Start): AD Users & Computers"
  $shortcutPath = "$env:AllUsersProfile\Desktop\AD Users & Computers.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = "%HOMEDRIVE%%HOMEPATH%"
  $shortcut.TargetPath = "%SystemRoot%\system32\dsa.msc"
  $shortcut.Save()
  Write-Host "Customize (End): AD Users & Computers"

  Write-Host "Customize (Start): NFS Server"
  Install-WindowsFeature -Name "FS-NFS-Service"
  Write-Host "Customize (End): NFS Server"
} else {
  Write-Host "Customize (Start): AD Tools"
  $installType = "ad-tools" # RSAT: Active Directory Domain Services and Lightweight Directory Services Tools
  StartProcess dism.exe "/Online /Add-Capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 /NoRestart" "$binDirectory\$installType"
  Write-Host "Customize (End): AD Tools"

  Write-Host "Customize (Start): NFS Client"
  $installType = "nfs-client"
  StartProcess dism.exe "/Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All /NoRestart" "$binDirectory\$installType"
  Write-Host "Customize (End): NFS Client"
}

if ($machineType -ne "Storage") {
  $versionInfo = "10.3.0.13"
  $installRoot = "C:\deadline"
  $databaseHost = $(hostname)
  $databasePort = 27100
  $databasePath = "C:\deadlineData"
  $certificateFile = "Deadline10Client.pfx"
  $binPathScheduler = "$installRoot\bin"

  Write-Host "Customize (Start): Deadline Download"
  $installFile = "Deadline-$versionInfo-windows-installers.zip"
  $downloadUrl = "$binStorageHost/Deadline/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Deadline Download"

  Set-Location -Path Deadline*
  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Deadline Server"
    $installType = "deadline-repository"
    $installFile = "DeadlineRepository-$versionInfo-windows-installer.exe"
    StartProcess .\$installFile "--mode unattended --dbLicenseAcceptance accept --prefix $installRoot --dbhost $databaseHost --mongodir $databasePath --installmongodb true" "$binDirectory\$installType"
    Copy-Item -Path $env:TMP\installbuilder_installer.log -Destination $binDirectory\$installType.log
    Copy-Item -Path $databasePath\certs\$certificateFile -Destination $installRoot\$certificateFile
    New-NfsShare -Name "Deadline" -Path $installRoot -Permission ReadWrite
    Write-Host "Customize (End): Deadline Server"
  }

  Write-Host "Customize (Start): Deadline Client"
  $installType = "deadline-client"
  $installFile = "DeadlineClient-$versionInfo-windows-installer.exe"
  $installArgs = "--mode unattended --prefix $installRoot"
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
  StartProcess .\$installFile $installArgs "$binDirectory\$installType"
  Copy-Item -Path $env:TMP\installbuilder_installer.log -Destination $binDirectory\$installType.log
  Set-Location -Path $binDirectory
  Write-Host "Customize (End): Deadline Client"

  if ($machineType -ne "Scheduler") {
    Write-Host "Customize (Start): Deadline Monitor"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = $binPathScheduler
    $shortcut.TargetPath = "$binPathScheduler\deadlinemonitor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Deadline Monitor"
  }

  $binPaths += ";$binPathScheduler"
}

if ($machineType -eq "Farm") {
  Write-Host "Customize (Start): Privacy Experience"
  $registryKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
  New-Item -ItemType Directory -Path $registryKeyPath -Force
  New-ItemProperty -Path $registryKeyPath -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force
  Write-Host "Customize (End): Privacy Experience"
}

if ($machineType -eq "Workstation") {
  Write-Host "Customize (Start): HP Anyware"
  $versionInfo = "23.08"
  $installType = if ([string]::IsNullOrEmpty($gpuProvider)) {"pcoip-agent-standard"} else {"pcoip-agent-graphics"}
  $installFile = "${installType}_$versionInfo.2.exe"
  $downloadUrl = "$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "/S /NoPostReboot /Force" "$binDirectory\$installType"
  Write-Host "Customize (End): HP Anyware"
}

if ($binPaths -ne "") {
  setx PATH "$env:PATH$binPaths" /m
}
