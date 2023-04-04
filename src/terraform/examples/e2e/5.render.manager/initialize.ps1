$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

if (${renderManager} -like "*RoyalRender*") {
  $installType = "royal-render-server-init"
  Start-Process -FilePath "rrServerconsole" -ArgumentList "-initAndClose" -Wait -RedirectStandardOutput "$installType.output.log" -RedirectStandardError "$installType.error.log"
}

if (${renderManager} -like "*Qube*") {
  $installType = "qube-supervisor"
  Start-Process -FilePath "C:\Program Files\pfx\qube\utils\supe_postinstall.bat" -Wait -RedirectStandardOutput "$installType-post.output.log" -RedirectStandardError "$installType-post.error.log"
}

if (${qubeLicense.userName} -ne "") {
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

$customDataInputFile = "C:\AzureData\CustomData.bin"
$customDataOutputFile = "C:\AzureData\scale.auto.ps1"
$fileStream = New-Object System.IO.FileStream($customDataInputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$streamReader = New-Object System.IO.StreamReader($fileStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $customDataOutputFile -Force

$taskName = "AAA Compute Auto Scaler"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Seconds ${autoScale.detectionIntervalSeconds}
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $customDataOutputFile -resourceGroupName ${autoScale.resourceGroupName} -scaleSetName ${autoScale.scaleSetName} -jobWaitThresholdSeconds ${autoScale.jobWaitThresholdSeconds}"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
if (${autoScale.enable}) {
  $taskSettings = New-ScheduledTaskSettingsSet
} else {
  $taskSettings = New-ScheduledTaskSettingsSet -Disable
}
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User System -Force
