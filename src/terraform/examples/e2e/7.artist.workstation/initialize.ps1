$ErrorActionPreference = "Stop"

$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$functionsFile = "$binDirectory\functions.ps1"
$functionsCode = "${ filebase64("../0.global/functions.ps1") }"
$functionsBytes = [System.Convert]::FromBase64String($functionsCode)
[System.Text.Encoding]::UTF8.GetString($functionsBytes) | Out-File $functionsFile -Force
. $functionsFile

$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorage) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsStorageCache) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsRoyalRender) }"
$fsMountsFile = AddFileSystemMounts "${fileSystemMountsDelimiter}" "${ join(fileSystemMountsDelimiter, fileSystemMountsDeadline) }"
RegisterFileSystemMounts $fsMountsFile

if ("${renderManager}" -like "*RoyalRender*") {
  $installType = "royal-render-client"
  $serviceUser = "rrService"
  $servicePassword = ConvertTo-SecureString "${servicePassword}" -AsPlainText -Force
  New-LocalUser -Name $serviceUser -Password $servicePassword -PasswordNeverExpires
  Start-Process -FilePath "rrWorkstation_installer" -ArgumentList "-plugins -service -rrUser $serviceUser -rrUserPW ""${servicePassword}"" -fwOut" -Wait -RedirectStandardOutput "$installType-service.out.log" -RedirectStandardError "$installType-service.err.log"
}

if ("${teradiciLicenseKey}" != "") {
  $installType = "pcoip-agent-license"
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${teradiciLicenseKey}" -Wait -RedirectStandardOutput "$installType.out.log" -RedirectStandardError "$installType.err.log"
}
