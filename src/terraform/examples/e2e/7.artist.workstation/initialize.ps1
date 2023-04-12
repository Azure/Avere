$ErrorActionPreference = "Stop"

Set-Location -Path "C:\Users\Public\Downloads"

$functionsData = "C:\AzureData\CustomData.bin"
$functionsCode = "C:\AzureData\functions.ps1"
$fileStream = New-Object System.IO.FileStream($functionsData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$streamReader = New-Object System.IO.StreamReader($fileStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $functionsCode -Force
. $functionsCode

SetMount "${fsMount.storageRead}" "${fsMount.storageReadCache}" "${storageCache.enableRead}"
SetMount "${fsMount.storageWrite}" "${fsMount.storageWriteCache}" "${storageCache.enableWrite}"
if ("${renderManager}" -like "*Deadline*") {
  AddMount "${fsMount.schedulerDeadline}"
}
RegisterMounts

EnableRenderClient "${renderManager}" "${servicePassword}"

if ("${teradiciLicenseKey}" != "") {
  $installType = "pcoip-agent-license"
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
}
