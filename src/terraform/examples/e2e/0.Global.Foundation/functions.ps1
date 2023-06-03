$fileSystemMountPath = "C:\AzureData\fileSystemMount.bat"

function SetServiceAccount ($serviceAccount, $serviceAccountPassword) {
  $localUser = Get-LocalUser -Name $serviceAccount -ErrorAction SilentlyContinue
  if ($localUser -eq $null) {
    $servicePassword = ConvertTo-SecureString $serviceAccountPassword -AsPlainText -Force
    New-LocalUser -Name $serviceAccount -Password $servicePassword -PasswordNeverExpires -AccountNeverExpires
  }
}

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

function FileExists ($filePath) {
  return Test-Path -PathType Leaf -Path $filePath
}

function SetFileSystemMount ($fileSystemMount) {
  if (!(FileExists $fileSystemMountPath)) {
    New-Item -ItemType File -Path $fileSystemMountPath
  }
  $mountScript = Get-Content -Path $fileSystemMountPath
  if ($mountScript -eq $null -or $mountScript -notlike "*$fileSystemMount*") {
    Add-Content -Path $fileSystemMountPath -Value $fileSystemMount
  }
}

function RegisterFileSystemMount ($fileSystemMountPath) {
  if (FileExists $fileSystemMountPath) {
    StartProcess $fileSystemMountPath $null file-system-mount
    $taskName = "AAA File System Mount"
    $taskAction = New-ScheduledTaskAction -Execute $fileSystemMountPath
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
  }
}

function EnableSchedulerClient ($renderManager, $serviceAccount, $servicePassword) {
  if ("$renderManager" -like "*Deadline*") {
    deadlinecommand.exe -ChangeRepository Direct S:\ S:\Deadline10Client.pfx ""
  }
  # if ("$renderManager" -like "*RoyalRender*") {
  #   $installType = "royal-render-client"
  #   StartProcess rrWorkstation_installer.exe "-plugins -service -rrUser $serviceAccount -rrUserPW $servicePassword -fwOut" $installType-service
  # }
}
