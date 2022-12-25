$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$functionsFile = "$binDirectory\functions.ps1"
$functionsCode = "${ filebase64("../0.global/functions.ps1") }"
$functionsBytes = [System.Convert]::FromBase64String($functionsCode)
[System.Text.Encoding]::UTF8.GetString($functionsBytes) | Out-File $functionsFile -Force
& $functionsFile

%{ if teradiciLicenseKey != "" }
  $agentFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$agentFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "pcoip-agent.output.txt" -RedirectStandardError "pcoip-agent.error.txt"
%{ endif }

$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsQube) }"
$fsMountsFile = AddFileSystemMounts $binDirectory "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
RegisterFileSystemMounts $fsMountsFile
