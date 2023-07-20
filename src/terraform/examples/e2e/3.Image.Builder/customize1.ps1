param (
  [string] $buildConfigEncoded
)

$ErrorActionPreference = "Stop"

$binPaths = ""
$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

function StartProcess ($filePath, $argumentList, $logFile) {
  if ($logFile -eq $null) {
    if ($argumentList -eq $null) {
      Start-Process -FilePath $filePath -Wait
    } else {
      Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait
    }
  } else {
    if ($argumentList -eq $null) {
      Start-Process -FilePath $filePath -Wait -RedirectStandardError $logFile-err.log -RedirectStandardOutput $logFile-out.log
    } else {
      Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait -RedirectStandardError $logFile-err.log -RedirectStandardOutput $logFile-out.log
    }
    Get-Content -Path $logFile-err.log | Tee-Object -FilePath "$logFile.log" -Append
    Get-Content -Path $logFile-out.log | Tee-Object -FilePath "$logFile.log" -Append
    Remove-Item -Path $logFile-err.log, $logFile-out.log
  }
}

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
$renderManager = $buildConfig.renderManager
$renderEngines = $buildConfig.renderEngines
$binStorageHost = $buildConfig.binStorage.host
$binStorageAuth = $buildConfig.binStorage.auth
$servicePassword = $buildConfig.servicePassword
Write-Host "Machine Type: $machineType"
Write-Host "GPU Provider: $gpuProvider"
Write-Host "Render Manager: $renderManager"
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

if ($machineType -eq "Storage" -or $machineType -eq "Scheduler") {
  Write-Host "Customize (Start): Azure CLI"
  $installType = "azure-cli"
  $installFile = "$installType.msi"
  $downloadUrl = "https://aka.ms/installazurecliwindows"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess $installFile "/quiet /norestart /log $installType.log" $null
  Write-Host "Customize (End): Azure CLI"
}

Write-Host "Customize (Start): Chocolatey"
$installType = "chocolatey"
$installFile = "$installType.ps1"
$downloadUrl = "https://community.chocolatey.org/install.ps1"
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
StartProcess PowerShell.exe "-ExecutionPolicy Unrestricted -File .\$installFile" $installType
$binPathChoco = "C:\ProgramData\chocolatey"
$binPaths += ";$binPathChoco"
Write-Host "Customize (End): Chocolatey"

Write-Host "Customize (Start): Python"
$installType = "python"
StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" $installType
Write-Host "Customize (End): Python"

if ($machineType -eq "Workstation") {
  Write-Host "Customize (Start): Node.js"
  $installType = "nodejs"
  StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" $installType
  Write-Host "Customize (End): Node.js"
}

Write-Host "Customize (Start): Git"
$installType = "git"
StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" $installType
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
StartProcess .\$installFile "$componentIds --quiet --norestart" $installType
$binPathCMake = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$binPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\$versionInfo\BuildTools\MSBuild\Current\Bin\amd64"
$binPaths += ";$binPathCMake;$binPathMSBuild"
Write-Host "Customize (End): Visual Studio Build Tools"

if ($gpuProvider -eq "AMD") {
  $installType = "amd-gpu"
  if ($machineType -like "*NG*" -and $machineType -like "*v1*") {
    Write-Host "Customize (Start): AMD GPU (NG v1)"
    $installFile = "$installType.zip"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2234555"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Expand-Archive -Path $installFile
    $certStore = Get-Item -Path "cert:LocalMachine\TrustedPublisher"
    $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $filePath = ".\$installType\Packages\Drivers\Display\WT6A_INF\U0388197.cat"
    $signature = Get-AuthenticodeSignature -FilePath $filePath
    $certStore.Add($signature.SignerCertificate)
    $filePath = ".\$installType\Packages\Drivers\Display\WT6A_INF\amdfdans\AMDFDANS.cat"
    $signature = Get-AuthenticodeSignature -FilePath $filePath
    $certStore.Add($signature.SignerCertificate)
    $certStore.Close()
    StartProcess .\$installType\Setup.exe "-install -log $binDirectory\$installType.log" $null
    Write-Host "Customize (End): AMD GPU (NG v1)"
  } elseif ($machineType -like "*NV*" -and $machineType -like "*v4*") {
    Write-Host "Customize (Start): AMD GPU (NV v4)"
    $installFile = "$installType.exe"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess .\$installFile /S $null
    StartProcess C:\AMD\AMD*\Setup.exe "-install -log $binDirectory\$installType.log" $null
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
  $versionInfo = "12.2.0"
  $installType = "nvidia-gpu-cuda"
  $installFile = "cuda_${versionInfo}_windows_network.exe"
  $downloadUrl = "$binStorageHost/NVIDIA/CUDA/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "-s -n -log:$binDirectory\$installType" $null
  Write-Host "Customize (End): NVIDIA GPU (CUDA)"

  Write-Host "Customize (Start): NVIDIA OptiX"
  $versionInfo = "7.7.0"
  $installType = "nvidia-optix"
  $installFile = "NVIDIA-OptiX-SDK-$versionInfo-win64-32649046.exe"
  $downloadUrl = "$binStorageHost/NVIDIA/OptiX/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "/S" $null
  $sdkDirectory = "C:\ProgramData\NVIDIA Corporation\OptiX SDK $versionInfo\SDK"
  $buildDirectory = "$sdkDirectory\build"
  New-Item -ItemType Directory $buildDirectory
  $versionInfo = "v12.2"
  StartProcess $binPathCMake\cmake.exe "-B ""$buildDirectory"" -S ""$sdkDirectory"" -D CUDA_TOOLKIT_ROOT_DIR=""C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\$versionInfo""" $installType-cmake
  StartProcess $binPathMSBuild\MSBuild.exe """$buildDirectory\OptiX-Samples.sln"" -p:Configuration=Release" $installType-msbuild
  $binPaths += ";$buildDirectory\bin\Release"
  Write-Host "Customize (End): NVIDIA OptiX"
}

if ($renderEngines -contains "Maya") {
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
  StartProcess $binPathGit\git.exe "clone --recursive https://github.com/mmp/$installType.git" $installType-git
  New-Item -ItemType Directory -Path $installPathV3 -Force
  StartProcess $binPathCMake\cmake.exe "-B ""$installPathV3"" -S $binDirectory\$installType" $installType-cmake
  StartProcess $binPathMSBuild\MSBuild.exe """$installPathV3\PBRT-$versionInfo.sln"" -p:Configuration=Release" $installType-msbuild
  New-Item -ItemType SymbolicLink -Target $installPathV3\Release\pbrt.exe -Path $installPath\pbrt3.exe
  Write-Host "Customize (End): PBRT v3"

  Write-Host "Customize (Start): PBRT v4"
  $versionInfo = "v4"
  $installType = "pbrt-$versionInfo"
  $installPathV4 = "$installPath\$versionInfo"
  StartProcess $binPathGit\git.exe "clone --recursive https://github.com/mmp/$installType.git" $installType-git
  New-Item -ItemType Directory -Path $installPathV4 -Force
  StartProcess $binPathCMake\cmake.exe "-B ""$installPathV4"" -S $binDirectory\$installType" $installType-cmake
  StartProcess $binPathMSBuild\MSBuild.exe """$installPathV4\PBRT-$versionInfo.sln"" -p:Configuration=Release" $installType-msbuild
  New-Item -ItemType SymbolicLink -Target $installPathV4\Release\pbrt.exe -Path $installPath\pbrt4.exe
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
  StartProcess .\$installFile "/S /AcceptEULA=$versionEULA $installArgs" $installType
  $binPaths += ";C:\Program Files\Side Effects Software\Houdini $versionInfo\bin"
  Write-Host "Customize (End): Houdini"
}

if ($renderEngines -contains "Blender") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.6.0"
  $installType = "blender"
  $installFile = "$installType-$versionInfo-windows-x64.msi"
  $downloadUrl = "$binStorageHost/Blender/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess $installFile "/quiet /norestart /log $installType.log" $null
  $binPaths += ";C:\Program Files\Blender Foundation\Blender 3.6"
  Write-Host "Customize (End): Blender"
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
  StartProcess .\$installFile "$componentIds --quiet --norestart" $installType
  Write-Host "Customize (End): Visual Studio Workloads"

  Write-Host "Customize (Start): Unreal Engine Setup"
  $installType = "dotnet-fx3"
  StartProcess dism.exe "/Enable-Feature /FeatureName:NetFX3 /Online /All /NoRestart" $installType
  Set-Location -Path C:\
  $versionInfo = "5.2.1"
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

  StartProcess $installFile $null $installType-setup
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
  StartProcess $installFile $null unreal-project-files-generate
  Write-Host "Customize (End): Unreal Project Files Generate"

  Write-Host "Customize (Start): Unreal Engine Build"
  [System.Environment]::SetEnvironmentVariable("MSBuildEnableWorkloadResolver", "false")
  [System.Environment]::SetEnvironmentVariable("MSBuildSDKsPath", "$installPath\Engine\Binaries\ThirdParty\DotNet\6.0.302\windows\sdk\6.0.302\Sdks")
  StartProcess $binPathMSBuild\MSBuild.exe """$installPath\UE5.sln"" -p:Configuration=""Development Editor"" -p:Platform=Win64 -restore" $installType-msbuild
  Write-Host "Customize (End): Unreal Engine Build"

  if ($renderEngines -contains "Unreal+PixelStream") {
    Write-Host "Customize (Start): Unreal Pixel Streaming"
    $versionInfo = "5.2-0.6.5"
    $installType = "unreal-stream"
    $installFile = "UE$versionInfo.zip"
    $downloadUrl = "$binStorageHost/Unreal/PixelStream/$versionInfo/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    Expand-Archive -Path $installFile
    $installFile = "UE$versionInfo\PixelStreamingInfrastructure-UE$versionInfo\SignallingWebServer\platform_scripts\cmd\setup.bat"
    StartProcess .\$installFile $null $installType-signalling
    $installFile = "UE$versionInfo\PixelStreamingInfrastructure-UE$versionInfo\Matchmaker\platform_scripts\cmd\setup.bat"
    StartProcess .\$installFile $null $installType-matchmaker
    $installFile = "UE$versionInfo\PixelStreamingInfrastructure-UE$versionInfo\SFU\platform_scripts\cmd\setup.bat"
    StartProcess .\$installFile $null $installType-sfu
    Write-Host "Customize (End): Unreal Pixel Streaming"
  }

  $binPathUnreal = "$installPath\Engine\Binaries\Win64"
  $binPaths += ";$binPathUnreal"

  if ($machineType -eq "Workstation") {
    Write-Host "Customize (Start): Unreal Editor"
    netsh advfirewall firewall add rule name="Allow Unreal Editor" dir=in action=allow program="$binPathUnreal\UnrealEditor.exe"
    $shortcutPath = "$env:AllUsersProfile\Desktop\Unreal Editor.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$binPathUnreal"
    $shortcut.TargetPath = "$binPathUnreal\UnrealEditor.exe"
    $shortcut.Save()
    Write-Host "Customize (End): Unreal Editor"
  }
}

if ($binPaths -ne "") {
  setx PATH "$env:PATH$binPaths" /m
}
