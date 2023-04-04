$ErrorActionPreference = "Stop"

$functionsFile = "C:\Users\Public\Downloads\functions.ps1"
$functionsCode = "${ filebase64("../0.global/functions.ps1") }"
$functionsBytes = [System.Convert]::FromBase64String($functionsCode)
[System.Text.Encoding]::UTF8.GetString($functionsBytes) | Out-File $functionsFile -Force
. $functionsFile

$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsRoyalRender) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
RegisterFileSystemMounts $fsMountsFile

if (${teradiciLicenseKey} != "") {
  $agentFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$agentFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "pcoip-agent.output.log" -RedirectStandardError "pcoip-agent.error.log"
}
