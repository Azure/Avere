$binDirectory = "C:\Users\Public\Downloads"
Set-Location -Path $binDirectory

$scriptFile = "C:\AzureData\functions.ps1"
Copy-Item -Path "C:\AzureData\CustomData.bin" -Destination $scriptFile
. $scriptFile

if ("${pcoipLicenseKey}" -ne "") {
  $installFile = "C:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
  StartProcess PowerShell.exe "-ExecutionPolicy Unrestricted -File ""$installFile"" -RegistrationCode ${pcoipLicenseKey}" $binDirectory/pcoip-agent-license
}

SetFileSystems $binDirectory '${jsonencode(fileSystems)}'

InitializeClient $binDirectory '${jsonencode(activeDirectory)}'
