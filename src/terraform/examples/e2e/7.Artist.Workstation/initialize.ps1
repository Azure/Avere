$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

$serviceAccountName = "${serviceAccountName}"
if ("${activeDirectory.domainName}" -ne "") {
  JoinDomainComputer "${activeDirectory.domainName}" "${activeDirectory.serverName}" "${activeDirectory.adminUsername}" "${activeDirectory.adminPassword}"
  $serviceAccountName = "${activeDirectory.domainName}\$serviceAccountName"
} else {
  SetLocalUser $serviceAccountName ${serviceAccountPassword}
}

$fileSystemMounts = ConvertFrom-Json -InputObject '${jsonencode(fileSystemMounts)}'
foreach ($fileSystemMount in $fileSystemMounts) {
  if ($fileSystemMount.enable -eq $true) {
    SetFileSystemMount $fileSystemMount.mount
  }
}
RegisterFileSystemMountPath

EnableClientApp "${renderManager}" $serviceAccountName ${serviceAccountPassword}

if (${teradiciLicenseKey} != "") {
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  StartProcess PowerShell.exe "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${teradiciLicenseKey}" pcoip-agent-license
}

if ("${activeDirectory.domainName}" -ne "") {
  Restart-Computer -Force
}
