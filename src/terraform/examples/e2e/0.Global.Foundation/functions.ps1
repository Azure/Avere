$fileSystemMountPath = "C:\AzureData\fileSystemMount.bat"

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

function SetMount ($storageMount, $storageCacheMount, $enableStorageCache) {
  if ($enableStorageCache -eq $true) {
    AddMount $storageCacheMount
  } else {
    AddMount $storageMount
  }
}

function AddMount ($fileSystemMount) {
  if (!(Test-Path -PathType Leaf -Path $fileSystemMountPath)) {
    New-Item -ItemType File -Path $fileSystemMountPath
  }
  $mountScript = Get-Content -Path $fileSystemMountPath
  if ($mountScript -eq $null -or $mountScript -notlike "*$fileSystemMount*") {
    Add-Content -Path $fileSystemMountPath -Value $fileSystemMount
  }
}

function EnableRenderClient ($renderManager, $servicePassword) {
  if ("$renderManager" -like "*Deadline*") {
    deadlinecommand.exe -ChangeRepository Direct S:\ S:\Deadline10Client.pfx ""
  }
  # if ("$renderManager" -like "*RoyalRender*") {
  #   $installType = "royal-render-client"

  #   $installPath = "RoyalRender*"
  #   $installFile = "rrSetup_win.exe"
  #   $rrRootShare = "\\scheduler.content.studio\RoyalRender"
  #   StartProcess .\$installPath\$installPath\$installFile "-console -rrRoot $rrRootShare" $installType

  #   $serviceUser = "rrService"
  #   $servicePwd = ConvertTo-SecureString "$servicePassword" -AsPlainText -Force
  #   New-LocalUser -Name $serviceUser -Password $servicePwd -PasswordNeverExpires
  #   StartProcess $rrRootShare\bin\win64\rrWorkstation_installer.exe "-plugins -service -rrUser $serviceUser -rrUserPW $servicePassword -fwOut" $installType-service
  # }
}
