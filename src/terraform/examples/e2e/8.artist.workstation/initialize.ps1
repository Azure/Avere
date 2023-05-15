$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

if ("${fileSystemMount.enable}" -eq "true") {
  SetMount "${fileSystemMount.storageRead}" "${fileSystemMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fileSystemMount.storageWrite}" "${fileSystemMount.storageWriteCache}" "${storageCache.enableWrite}"
  if ("${renderManager}" -like "*Deadline*") {
    AddMount "${fileSystemMount.schedulerDeadline}"
  }
  $installType = "file-system-mount"
  Start-Process -FilePath $fileSystemMountPath -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
}

EnableRenderClient "${renderManager}" "${servicePassword}"

if ("${teradiciLicenseKey}" != "") {
  $installType = "pcoip-agent-license"
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
}
