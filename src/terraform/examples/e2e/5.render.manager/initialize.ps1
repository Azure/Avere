$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

if ("${renderManager}" -like "*RoyalRender*") {
  $installType = "royal-render-server"
  $serviceUser = "rrService"
  $servicePassword = ConvertTo-SecureString "${servicePassword}" -AsPlainText -Force
  New-LocalUser -Name $serviceUser -Password $servicePassword -PasswordNeverExpires
  Start-Process -FilePath "rrServerconsole.exe" -ArgumentList "-initAndClose" -Wait -RedirectStandardOutput "$installType-init.out.log" -RedirectStandardError "$installType-init.err.log"
  Start-Process -FilePath "rrWorkstation_installer.exe" -ArgumentList "-serviceServer -rrUser $serviceUser -rrUserPW ""${servicePassword}"" -fwIn" -Wait -RedirectStandardOutput "$installType-service.out.log" -RedirectStandardError "$installType-service.err.log"
}

if ("${renderManager}" -like "*Qube*") {
  $installType = "qube-supervisor"
  Start-Process -FilePath "C:\Program Files\pfx\qube\utils\supe_postinstall.bat" -Wait -RedirectStandardOutput "$installType-post.out.log" -RedirectStandardError "$installType-post.err.log"
}

if ("${qubeLicense.userName}" -ne "") {
  $configFilePath = "C:\ProgramData\pfx\qube\dra.conf"
  if (!(Test-Path -PathType Leaf -Path $configFilePath)) {
    Copy-Item -Path "C:\Program Files\pfx\qube\dra\dra.conf.default" -Destination $configFilePath
  }
  $configFileText = Get-Content -Path $configFilePath
  $configFileText = $configFileText.Replace("#mls_user =", "mls_user = ${qubeLicense.userName}")
  $configFileText = $configFileText.Replace("#mls_password =", "mls_password = ${qubeLicense.userPassword}")
  Set-Content -Path $configFilePath -Value $configFileText
  Restart-Service -Name "qubedra"
}

$autoScaleData = "C:\AzureData\CustomData.bin"
$autoScaleCode = "C:\AzureData\aaa-scale.ps1"
$fileStream = New-Object System.IO.FileStream($autoScaleData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$streamReader = New-Object System.IO.StreamReader($fileStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $autoScaleCode -Force

$taskName = "AAA Auto Scale"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Seconds ${autoScale.detectionIntervalSeconds}
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $autoScaleCode -resourceGroupName ${autoScale.resourceGroupName} -scaleSetName ${autoScale.scaleSetName} -jobWaitThresholdSeconds ${autoScale.jobWaitThresholdSeconds}"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
if ("${autoScale.enable}" -ne "false") {
  $taskSettings = New-ScheduledTaskSettingsSet
} else {
  $taskSettings = New-ScheduledTaskSettingsSet -Disable
}
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User System -Force
