$fileSystemMountPath = "C:\AzureData\fileSystemMount.bat"

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
  if ($renderManager -like "*Deadline*") {
    Start-Process -FilePath "deadlinecommand.exe" -ArgumentList "-ChangeRepository Direct S:\ S:\Deadline10Client.pfx ''" -Wait
  }
  # if ($renderManager -like "*RoyalRender*") {
  #   $installType = "royal-render-client"

  #   $installPath = "RoyalRender*"
  #   $installFile = "rrSetup_win.exe"
  #   $rrRootShare = "\\scheduler.content.studio\RoyalRender"
  #   Start-Process -FilePath .\$installPath\$installPath\$installFile -ArgumentList "-console -rrRoot $rrRootShare" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"

  #   $serviceUser = "rrService"
  #   $servicePwd = ConvertTo-SecureString "$servicePassword" -AsPlainText -Force
  #   New-LocalUser -Name $serviceUser -Password $servicePwd -PasswordNeverExpires
  #   Start-Process -FilePath "$rrRootShare\bin\win64\rrWorkstation_installer.exe" -ArgumentList "-plugins -service -rrUser $serviceUser -rrUserPW ""$servicePassword"" -fwOut" -Wait -RedirectStandardOutput "$installType-service.out.log" -RedirectStandardError "$installType-service.err.log"
  # }
}
