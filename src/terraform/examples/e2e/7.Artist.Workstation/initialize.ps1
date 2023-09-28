$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

$fileSystemMounts = ConvertFrom-Json -InputObject '${jsonencode(fileSystemMounts)}'
foreach ($fileSystemMount in $fileSystemMounts) {
  if ($fileSystemMount.enable -eq $true) {
    SetFileSystemMount $fileSystemMount.mount
  }
}
RegisterFileSystemMountPath $binDirectory

EnableFarmClient

if ("${pcoipLicenseKey}" -ne "") {
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  StartProcess PowerShell.exe "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${pcoipLicenseKey}" $binDirectory/pcoip-agent-license
}

if ("${activeDirectory.enable}" -eq $true) {
  Retry 5 10 {
    JoinActiveDirectory ${activeDirectory.domainName} ${activeDirectory.domainServerName} "${activeDirectory.orgUnitPath}" ${activeDirectory.adminUsername} ${activeDirectory.adminPassword}
  }
}
