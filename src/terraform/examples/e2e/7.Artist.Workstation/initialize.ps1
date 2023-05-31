$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

if ("${fileSystemMount.enable}" -eq $true) {
  SetMount "${fileSystemMount.storageRead}" "${fileSystemMount.storageReadCache}" "${storageCache.enableRead}"
  SetMount "${fileSystemMount.storageWrite}" "${fileSystemMount.storageWriteCache}" "${storageCache.enableWrite}"
  if ("${renderManager}" -like "*Deadline*") {
    AddMount "${fileSystemMount.schedulerDeadline}"
  }
  StartProcess $fileSystemMountPath $null file-system-mount
}

EnableRenderClient "${renderManager}" "${servicePassword}"

if (${teradiciLicenseKey} != "") {
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  StartProcess PowerShell.exe "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${teradiciLicenseKey}" pcoip-agent-license
}
