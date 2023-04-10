$fsMountsFile = "C:\Windows\fs-mounts.bat"

function SetMount ($storageMount, $storageCacheMount, $enableStorageCache) {
  if ($enableStorageCache -eq "true") {
    AddMount $storageCacheMount
  } else {
    AddMount $storageMount
  }
}

function AddMount ($fsMount) {
  if (!(Test-Path -PathType Leaf -Path $fsMountsFile)) {
    New-Item -ItemType File -Path $fsMountsFile
  }
  $fsMountsFileText = Get-Content -Path $fsMountsFile
  if ($fsMountsFileText -eq $null -or $fsMountsFileText -notlike "*$fsMount*") {
    Add-Content -Path $fsMountsFile -Value $fsMount
  }
}

function RegisterMounts () {
  $installType = "fs-mounts"
  $fsMountsFileSize = (Get-Item -Path $fsMountsFile).Length
  if ($fsMountsFileSize -gt 0) {
    $taskName = "AAA File System Mounts"
    $taskAction = New-ScheduledTaskAction -Execute $fsMountsFile
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
    Start-Process -FilePath $fsMountsFile -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
  }
}

function EnableRenderClient ($renderManager, $servicePassword) {
  if ("$renderManager" -like "*RoyalRender*") {
    $installType = "royal-render-client"
    $serviceUser = "rrService"
    $servicePwd = ConvertTo-SecureString "$servicePassword" -AsPlainText -Force
    New-LocalUser -Name $serviceUser -Password $servicePwd -PasswordNeverExpires
    Start-Process -FilePath "rrWorkstation_installer" -ArgumentList "-plugins -service -rrUser $serviceUser -rrUserPW ""$servicePassword"" -fwOut" -Wait -RedirectStandardOutput "$installType-service.out.log" -RedirectStandardError "$installType-service.err.log"
  }
}
