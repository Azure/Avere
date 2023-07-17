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

if ($machineType -eq "Scheduler" -and ("$renderManager" -like "*Deadline*" -or "$renderManager" -like "*RoyalRender*")) {
  Write-Host "Customize (Start): NFS Server"
  Install-WindowsFeature -Name "FS-NFS-Service"
  Write-Host "Customize (End): NFS Server"
} else {
  Write-Host "Customize (Start): NFS Client"
  $installType = "nfs-client"
  StartProcess dism.exe "/Enable-Feature /FeatureName:ClientForNFS-Infrastructure /Online /All /NoRestart" $installType
  Write-Host "Customize (End): NFS Client"
}

if ("$renderManager" -like "*Deadline*") {
  $versionInfo = "10.2.1.0"
  $installRoot = "C:\Deadline"
  $databaseHost = $(hostname)
  $databasePort = 27100
  $databasePath = "C:\DeadlineDatabase"
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
    netsh advfirewall firewall add rule name="Allow Deadline Database" dir=in action=allow protocol=TCP localport=$databasePort
    $installType = "deadline-repository"
    $installFile = "DeadlineRepository-$versionInfo-windows-installer.exe"
    StartProcess .\$installFile "--mode unattended --dbLicenseAcceptance accept --prefix $installRoot --dbhost $databaseHost --mongodir $databasePath --installmongodb true" $null
    Move-Item -Path $env:TMP\installbuilder_installer.log -Destination $binDirectory\deadline-repository.log
    Copy-Item -Path $databasePath\certs\$certificateFile -Destination $installRoot\$certificateFile
    New-NfsShare -Name "Deadline" -Path $installRoot -Permission ReadWrite
    Write-Host "Customize (End): Deadline Server"
  }

  Write-Host "Customize (Start): Deadline Client"
  netsh advfirewall firewall add rule name="Allow Deadline Worker" dir=in action=allow program="$binPathScheduler\deadlineworker.exe"
  netsh advfirewall firewall add rule name="Allow Deadline Monitor" dir=in action=allow program="$binPathScheduler\deadlinemonitor.exe"
  netsh advfirewall firewall add rule name="Allow Deadline Launcher" dir=in action=allow program="$binPathScheduler\deadlinelauncher.exe"
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
  StartProcess .\$installFile $installArgs $null
  Copy-Item -Path $env:TMP\installbuilder_installer.log -Destination $binDirectory\deadline-client.log
  Set-Location -Path $binDirectory
  Write-Host "Customize (End): Deadline Client"

  Write-Host "Customize (Start): Deadline Monitor"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Deadline Monitor.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $binPathScheduler
  $shortcut.TargetPath = "$binPathScheduler\deadlinemonitor.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Deadline Monitor"

  $binPaths += ";$binPathScheduler"
}

if ("$renderManager" -like "*RoyalRender*") {
  $versionInfo = "9.0.07"
  $installRoot = "\RoyalRender"
  $binPathScheduler = "C:$installRoot\bin\win64"

  Write-Host "Customize (Start): Royal Render Download"
  $installFile = "RoyalRender__${versionInfo}__installer.zip"
  $downloadUrl = "$binStorageHost/RoyalRender/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  Expand-Archive -Path $installFile
  Write-Host "Customize (End): Royal Render Download"

  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Royal Render Server"
    netsh advfirewall set public state off
    $installType = "royal-render"
    $installPath = "RoyalRender*"
    $installFile = "rrSetup_win.exe"
    $rrShareName = $installRoot.TrimStart("\")
    $rrRootShare = "\\$(hostname)$installRoot"
    New-Item -ItemType Directory -Path $installRoot
    New-SmbShare -Name $rrShareName -Path "C:$installRoot" -FullAccess "Everyone"
    StartProcess .\$installPath\$installPath\$installFile "-console -rrRoot $rrRootShare" $installType
    Remove-SmbShare -Name $rrShareName -Force
    New-NfsShare -Name "RoyalRender" -Path C:$installRoot -Permission ReadWrite
    Write-Host "Customize (End): Royal Render Server"
  } else {
    $binPathScheduler = "T:\bin\win64"
  }

  $binPaths += ";$binPathScheduler"

  Write-Host "Customize (Start): Royal Render Submitter"
  $shortcutPath = "$env:AllUsersProfile\Desktop\Royal Render Submitter.lnk"
  $scriptShell = New-Object -ComObject WScript.Shell
  $shortcut = $scriptShell.CreateShortcut($shortcutPath)
  $shortcut.WorkingDirectory = $binPathScheduler
  $shortcut.TargetPath = "$binPathScheduler\rrSubmitter.exe"
  $shortcut.Save()
  Write-Host "Customize (End): Royal Render Submitter"
}

if ("$renderManager" -like "*Qube*") {
  $versionInfo = "8.0-0"
  $installRoot = "C:\Program Files\pfx\qube"
  $binPathScheduler = "$installRoot\bin"

  Write-Host "Customize (Start): Strawberry Perl"
  $installType = "strawberryperl"
  StartProcess $binPathChoco\choco.exe "install $installType --confirm --no-progress" $installType
  Write-Host "Customize (End): Strawberry Perl"

  Write-Host "Customize (Start): Qube Core"
  $installType = "qube-core"
  $installFile = "$installType-$versionInfo-WIN32-6.3-x64.msi"
  $downloadUrl = "$binStorageHost/Qube/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess $installFile "/quiet /norestart /log $installType.log" $null
  Write-Host "Customize (End): Qube Core"

  if ($machineType -eq "Scheduler") {
    Write-Host "Customize (Start): Qube Supervisor"
    netsh advfirewall firewall add rule name="Allow Qube Database" dir=in action=allow protocol=TCP localport=50055
    netsh advfirewall firewall add rule name="Allow Qube Supervisor (TCP)" dir=in action=allow protocol=TCP localport=50001,50002
    netsh advfirewall firewall add rule name="Allow Qube Supervisor (UDP)" dir=in action=allow protocol=UDP localport=50001,50002
    netsh advfirewall firewall add rule name="Allow Qube Supervisor Proxy" dir=in action=allow protocol=TCP localport=50555,50556
    $installType = "qube-supervisor"
    $installFile = "$installType-${versionInfo}-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$versionInfo/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess $installFile "/quiet /norestart /log $installType.log" $null
    $binPaths += ";C:\Program Files\pfx\pgsql\bin"
    Write-Host "Customize (End): Qube Supervisor"

    Write-Host "Customize (Start): Qube Data Relay Agent (DRA)"
    netsh advfirewall firewall add rule name="Allow Qube Data Relay Agent (DRA)" dir=in action=allow protocol=TCP localport=5001
    $installType = "qube-dra"
    $installFile = "$installType-$versionInfo-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$versionInfo/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess $installFile "/quiet /norestart /log $installType.log" $null
    Write-Host "Customize (End): Qube Data Relay Agent (DRA)"
  } else {
    Write-Host "Customize (Start): Qube Worker"
    netsh advfirewall firewall add rule name="Allow Qube Worker (TCP)" dir=in action=allow protocol=TCP localport=50011
    netsh advfirewall firewall add rule name="Allow Qube Worker (UDP)" dir=in action=allow protocol=UDP localport=50011
    $installType = "qube-worker"
    $installFile = "$installType-$versionInfo-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$versionInfo/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess $installFile "/quiet /norestart /log $installType.log" $null
    Write-Host "Customize (End): Qube Worker"

    Write-Host "Customize (Start): Qube Client"
    $installType = "qube-client"
    $installFile = "$installType-$versionInfo-WIN32-6.3-x64.msi"
    $downloadUrl = "$binStorageHost/Qube/$versionInfo/$installFile$binStorageAuth"
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
    StartProcess $installFile "/quiet /norestart /log $installType.log" $null
    $shortcutPath = "$env:AllUsersProfile\Desktop\Qube Client.lnk"
    $scriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $scriptShell.CreateShortcut($shortcutPath)
    $shortcut.WorkingDirectory = "$installRoot\QubeUI"
    $shortcut.TargetPath = "$installRoot\QubeUI\QubeUI.bat"
    $shortcut.IconLocation = "$installRoot\lib\install\qube_icon.ico"
    $shortcut.Save()
    Write-Host "Customize (End): Qube Client"

    $configFile = "C:\ProgramData\pfx\qube\qb.conf"
    $configFileText = Get-Content -Path $configFile
    $configFileText = $configFileText.Replace("#qb_supervisor =", "qb_supervisor = scheduler.artist.studio")
    $configFileText = $configFileText.Replace("#worker_cpus = 0", "worker_cpus = 1")
    Set-Content -Path $configFile -Value $configFileText
  }

  $binPaths += ";$binPathScheduler;$installRoot\sbin"
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
  $versionInfo = "23.04.1"
  $installType = if ([string]::IsNullOrEmpty($gpuProvider)) {"pcoip-agent-standard"} else {"pcoip-agent-graphics"}
  $installFile = "${installType}_$versionInfo.exe"
  $downloadUrl = "$binStorageHost/Teradici/$versionInfo/$installFile$binStorageAuth"
  (New-Object System.Net.WebClient).DownloadFile($downloadUrl, (Join-Path -Path $pwd.Path -ChildPath $installFile))
  StartProcess .\$installFile "/S /NoPostReboot /Force" $installType
  Write-Host "Customize (End): Teradici PCoIP"
}

if ($binPaths -ne "") {
  setx PATH "$env:PATH$binPaths" /m
}
