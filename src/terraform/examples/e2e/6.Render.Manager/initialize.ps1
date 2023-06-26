$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$securePassword = ConvertTo-SecureString ${serviceAccountPassword} -AsPlainText -Force
New-LocalUser -Name ${serviceAccountName} -Password $securePassword -PasswordNeverExpires -AccountNeverExpires

function StartProcess ($filePath, $argumentList, $logFile) {
  if ($argumentList -eq $null) {
    Start-Process -FilePath $filePath -Wait -RedirectStandardError $logFile-err.log -RedirectStandardOutput $logFile-out.log
  } else {
    Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait -RedirectStandardError $logFile-err.log -RedirectStandardOutput $logFile-out.log
  }
  Get-Content -Path $logFile-err.log | Tee-Object -FilePath "$logFile.log" -Append
  Get-Content -Path $logFile-out.log | Tee-Object -FilePath "$logFile.log" -Append
  Remove-Item -Path $logFile-err.log, $logFile-out.log
}

if ("${renderManager}" -like "*Deadline*") {
  StartProcess sc.exe "start Deadline10DatabaseService" deadline-database-service
}

if ("${renderManager}" -like "*RoyalRender*") {
  $installType = "royal-render-server"
  StartProcess rrServerconsole.exe "-initAndClose" $installType-init
  StartProcess rrWorkstation_installer.exe "-serviceServer -rrUser ${serviceAccountName} -rrUserPW ${serviceAccountPassword} -fwIn" $installType-service
}

if ("${renderManager}" -like "*Qube*") {
  StartProcess "C:\Program Files\pfx\qube\utils\supe_postinstall.bat" $null qube-supervisor-post
  if (${qubeLicense.userName} -ne "") {
    $configFile = "C:\ProgramData\pfx\qube\dra.conf"
    if (!(Test-Path -PathType Leaf -Path $configFile)) {
      Copy-Item -Path "C:\Program Files\pfx\qube\dra\dra.conf.default" -Destination $configFile
    }
    $configFileText = Get-Content -Path $configFile
    $configFileText = $configFileText.Replace("#mls_user =", "mls_user = ${qubeLicense.userName}")
    $configFileText = $configFileText.Replace("#mls_password =", "mls_password = ${qubeLicense.userPassword}")
    Set-Content -Path $configFile -Value $configFileText
    Restart-Service -Name "qubedra"
  }
}

$scriptFile = "C:\AzureData\aaaScaler.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile

$taskName = "AAA Auto Scaler"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Seconds ${autoScale.detectionIntervalSeconds}
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $scriptFile -resourceGroupName ${autoScale.resourceGroupName} -scaleSetName ${autoScale.scaleSetName} -scaleSetMachineCountMax ${autoScale.scaleSetMachineCountMax} -jobWaitThresholdSeconds ${autoScale.jobWaitThresholdSeconds} -workerIdleDeleteSeconds ${autoScale.workerIdleDeleteSeconds}"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
if ("${autoScale.enable}" -ne $false) {
  $taskSettings = New-ScheduledTaskSettingsSet
} else {
  $taskSettings = New-ScheduledTaskSettingsSet -Disable
}
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User System -Force
