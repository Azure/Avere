param (
  [string] $buildJsonEncoded
)

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$storageContainerUrl = "https://azartist.blob.core.windows.net/bin"
$storageContainerSas = "?sv=2020-10-02&st=2022-01-01T00%3A00%3A00Z&se=2222-12-31T00%3A00%3A00Z&sr=c&sp=r&sig=4N8gUHTPNOG%2BlgEPvQljsRPCOsRD3ZWfiBKl%2BRxl9S8%3D"

Write-Host "Customize (Start): Image Build Parameters"
$buildJsonBytes = [System.Convert]::FromBase64String($buildJsonEncoded)
$buildJson = [System.Text.Encoding]::UTF8.GetString($buildJsonBytes)
$build = $buildJson | ConvertFrom-Json
$subnetName = $build.subnetName
Write-Host "Subnet Name: $subnetName"
$machineSize = $build.machineSize
Write-Host "Machine Size: $machineSize"
$renderEngines = $build.renderEngines -join ","
Write-Host "Render Engines: $renderEngines"
Write-Host "Customize (End): Image Build Parameters"

Write-Host "Customize (Start): Visual Studio Build Tools"
$installFile = "vs_BuildTools.exe"
$downloadUrl = "https://aka.ms/vs/17/release/$installFile"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Start-Process -FilePath .\$installFile -ArgumentList "--quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended --add Microsoft.VisualStudio.Workload.AzureBuildTools;includeRecommended" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
Write-Host "Customize (End): Visual Studio Build Tools"

Write-Host "Customize (Start): Git"
$versionInfo = "2.35.1.2"
$installFile = "Git-$versionInfo-64-bit.exe"
$downloadUrl = "$storageContainerUrl/Win/$installFile$storageContainerSas"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Start-Process -FilePath .\$installFile -ArgumentList "/SILENT /NORESTART" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
Write-Host "Customize (End): Git"

Write-Host "Customize (Start): Azure CLI"
$installFile = "az-cli.msi"
$downloadUrl = "https://aka.ms/installazurecliwindows"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installFile /quiet /norestart" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
Write-Host "Customize (End): Azure CLI"

#   NVv3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv3-series)
# NCT4v3 (https://docs.microsoft.com/en-us/azure/virtual-machines/nct4-v3-series)
if (($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v3")) -or
    ($machineSize.StartsWith("Standard_NC") -and $machineSize.EndsWith("T4_v3"))) {
  Write-Host "Customize (Start): GPU Driver (NVv3)"
  $installFile = "nvidia-gpu-nv3.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=874181"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/s /noreboot" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): GPU Driver (NVv3)"
}

# NVv4 (https://docs.microsoft.com/en-us/azure/virtual-machines/nvv4-series)
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v4")) {
  Write-Host "Customize (Start): GPU Driver (NVv4)"
  $installFile = "amd-gpu-nv4.exe"
  $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2175154"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/S" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): GPU Driver (NVv4)"
}

# NVv5 (https://docs.microsoft.com/en-us/azure/virtual-machines/nva10v5-series)
if ($machineSize.StartsWith("Standard_NV") -and $machineSize.EndsWith("_v5")) {
  Write-Host "Customize (Start): GPU Driver (NVv5)"
  $installFile = "nvidia-gpu-nv5.exe"
  $downloadUrl = "https://download.microsoft.com/download/8/d/2/8d228f28-56e2-4e60-bdde-a1dccfe94869/511.65_grid_win10_win11_server2016_server2019_server2022_64bit_Azure_swl.exe"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/s /noreboot" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): GPU Driver (NVv5)"
}

if ($subnetName -eq "Scheduler") {
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

$schedulerVersion = "10.1.20.2"
$schedulerLicense = "LicenseFree"
$schedulerPath = "C:\Program Files\Thinkbox\Deadline10\bin"
$schedulerDatabasePath = "C:\DeadlineDatabase"
$schedulerRepositoryPath = "C:\DeadlineRepository"
$schedulerCertificateFile = "Deadline10Client.pfx"
$schedulerRepositoryLocalMount = "S:\"
$schedulerRepositoryCertificate = "$schedulerRepositoryLocalMount$schedulerCertificateFile"

$rendererPaths = ""
$rendererPathBlender = "C:\Program Files\Blender Foundation\Blender3"
$rendererPathPBRTv3 = "C:\Program Files\PBRT3"
$rendererPathPBRTv4 = "C:\Program Files\PBRT4"
$rendererPathUnreal = "C:\Program Files\Epic Games\Unreal5"
$rendererPathMaya = "C:\Program Files\Autodesk\Maya2023"
$rendererPath3DSMax = "C:\Program Files\Autodesk\3ds Max 2023"
$rendererPathHoudini = "C:\Program Files\Side Effects Software\Houdini19"
if ($renderEngines -like "*Blender*") {
  $rendererPaths += ";$rendererPathBlender"
}
if ($renderEngines -like "*PBRTv3*") {
  $rendererPaths += ";$rendererPathPBRTv3\Release"
}
if ($renderEngines -like "*PBRTv4*") {
  $rendererPaths += ";$rendererPathPBRTv4\Release"
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

$toolPathGit = "C:\Program Files\Git\bin"
$toolPathVSIX = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE"
$toolPathCMake = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$toolPathMSBuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin"

Write-Host "Customize (Start): Deadline Download"
$installFile = "Deadline-$schedulerVersion-windows-installers.zip"
$downloadUrl = "$storageContainerUrl/Deadline/$schedulerVersion/$installFile$storageContainerSas"
Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
Expand-Archive -Path $installFile
Write-Host "Customize (End): Deadline Download"

if ($subnetName -eq "Scheduler") {
  Write-Host "Customize (Start): Deadline Repository"
  netsh advfirewall firewall add rule name="Allow Mongo Database" dir=in action=allow protocol=TCP localport=27100
  Set-Location -Path "Deadline*"
  $installFile = "DeadlineRepository-$schedulerVersion-windows-installer.exe"
  Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended --dbLicenseAcceptance accept --installmongodb true --mongodir $schedulerDatabasePath --prefix $schedulerRepositoryPath" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
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
if ($subnetName -eq "Scheduler") {
  $clientArgs = "--slavestartup false --launcherservice false"
} else {
  if ($subnetName -eq "Farm") {
    $workerStartup = "true"
  } else {
    $workerStartup = "false"
  }
  $clientArgs = "--slavestartup $workerStartup --launcherservice true"
}
Start-Process -FilePath .\$installFile -ArgumentList "--mode unattended $clientArgs" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
Copy-Item -Path $env:TMP\bitrock_installer.log -Destination $binDirectory\bitrock_installer_client.log
$deadlineCommandName = "ChangeLicenseMode"
Start-Process -FilePath "$schedulerPath\deadlinecommand.exe" -ArgumentList "-$deadlineCommandName $schedulerLicense" -Wait -RedirectStandardOutput "$deadlineCommandName-output.txt" -RedirectStandardError "$deadlineCommandName-error.txt"
$deadlineCommandName = "ChangeRepositorySkipValidation"
Start-Process -FilePath "$schedulerPath\deadlinecommand.exe" -ArgumentList "-$deadlineCommandName Direct $schedulerRepositoryLocalMount $schedulerRepositoryCertificate ''" -Wait -RedirectStandardOutput "$deadlineCommandName-output.txt" -RedirectStandardError "$deadlineCommandName-error.txt"
Set-Location -Path $binDirectory
Write-Host "Customize (End): Deadline Client"

if ($renderEngines -like "*Blender*") {
  Write-Host "Customize (Start): Blender"
  $versionInfo = "3.1.2"
  $installFile = "blender-$versionInfo-windows-x64.msi"
  $downloadUrl = "$storageContainerUrl/Blender/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i ' + $installFile + ' INSTALL_ROOT="' + $rendererPathBlender + '" /quiet /norestart') -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Blender"
}

if ($renderEngines -like "*PBRTv3*") {
  Write-Host "Customize (Start): PBRT v3"
  $versionInfo = "v3"
  Start-Process -FilePath "$toolPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait
  Start-Process -FilePath "$toolPathCMake\cmake.exe" -ArgumentList "-S $binDirectory\pbrt-$versionInfo -B ""$rendererPathPBRTv3""" -Wait -RedirectStandardOutput "cmake-pbrt-$versionInfo.output.txt" -RedirectStandardError "cmake-pbrt-$versionInfo.error.txt"
  Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRTv3\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "msbuild-pbrt-$versionInfo.output.txt" -RedirectStandardError "msbuild-pbrt-$versionInfo.error.txt"
  Write-Host "Customize (End): PBRT v3"
}

if ($renderEngines -like "*PBRTv4*") {
  Write-Host "Customize (Start): PBRT v4"
  $versionInfo = "v4"
  Start-Process -FilePath "$toolPathGit\git.exe" -ArgumentList "clone --recursive https://github.com/mmp/pbrt-$versionInfo.git" -Wait
  Start-Process -FilePath "$toolPathCMake\cmake.exe" -ArgumentList "-S $binDirectory\pbrt-$versionInfo -B ""$rendererPathPBRTv4""" -Wait -RedirectStandardOutput "cmake-pbrt-$versionInfo.output.txt" -RedirectStandardError "cmake-pbrt-$versionInfo.error.txt"
  Start-Process -FilePath "$toolPathMSBuild\MSBuild.exe" -ArgumentList """$rendererPathPBRTv4\PBRT-$versionInfo.sln"" -p:Configuration=Release" -Wait -RedirectStandardOutput "msbuild-pbrt-$versionInfo.output.txt" -RedirectStandardError "msbuild-pbrt-$versionInfo.error.txt"
  Write-Host "Customize (End): PBRT v4"
}

if ($renderEngines -like "*Unreal*") {
  Write-Host "Customize (Start): Unreal Engine"
  $installFile = "dism.exe"
  $featureName = "NetFX3"
  Start-Process -FilePath $installFile -ArgumentList "/Enable-Feature /FeatureName:$featureName /Online /All /NoRestart" -Wait -Verb RunAs
  $versionInfo = "5.0.1"
  $installFile = "UnrealEngine-$versionInfo-release.zip"
  $downloadUrl = "$storageContainerUrl/Unreal/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Expand-Archive -Path $installFile -DestinationPath "$rendererPathUnreal"
  Move-Item -Path "$rendererPathUnreal\Unreal*\*" -Destination "$rendererPathUnreal"
  $installFile = "$rendererPathUnreal\Setup.bat"
  $setupScript = Get-Content -Path $installFile
  $setupScript = $setupScript.Replace("/register", "/register /unattended")
  $setupScript = $setupScript.Replace("pause", "rem pause")
  Set-Content -Path $installFile -Value $setupScript
  Start-Process -FilePath "$installFile" -ArgumentList "--force" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Unreal Engine"
  if ($subnetName -eq "Workstation") {
    Write-Host "Customize (Start): Epic Games Launcher"
    $versionInfo = "13.3.0"
    $installFile = "EpicInstaller-$versionInfo.msi"
    $downloadUrl = "$storageContainerUrl/Unreal/$installFile$storageContainerSas"
    Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installFile /quiet /norestart" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
    Write-Host "Customize (End): Epic Games Launcher"
    Write-Host "Customize (Start): Visual Studio"
    $installFile = "VisualStudioSetup.exe"
    $downloadUrl = "$storageContainerUrl/Win/$installFile$storageContainerSas"
    Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
    Start-Process -FilePath .\$installFile -ArgumentList "--quiet --norestart" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
    $installFile = "UnrealVS.vsix"
    Start-Process -FilePath "$toolPathVSIX\VSIXInstaller.exe" -ArgumentList "/quiet /admin ""$rendererPathUnreal\Engine\Extras\UnrealVS\$installFile""" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
    Write-Host "Customize (End): Visual Studio"
  }
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
  if ($subnetName -eq "Workstation") {
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

if ($subnetName -eq "Farm") {
  Write-Host "Customize (Start): Privacy Experience"
  $registryKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"
  New-Item -ItemType Directory -Path $registryKeyPath -Force
  New-ItemProperty -Path $registryKeyPath -PropertyType DWORD -Name "DisablePrivacyExperience" -Value 1 -Force
  Write-Host "Customize (End): Privacy Experience"   
}

if ($subnetName -eq "Workstation") {
  Write-Host "Customize (Start): Teradici PCoIP Agent"
  $versionInfo = "22.01.1"
  $installFile = "pcoip-agent-graphics_$versionInfo.exe"
  $downloadUrl = "$storageContainerUrl/Teradici/$versionInfo/$installFile$storageContainerSas"
  Invoke-WebRequest -OutFile $installFile -Uri $downloadUrl
  Start-Process -FilePath .\$installFile -ArgumentList "/S /NoPostReboot /Force" -Wait -RedirectStandardOutput "$installFile.output.txt" -RedirectStandardError "$installFile.error.txt"
  Write-Host "Customize (End): Teradici PCoIP Agent"
}
