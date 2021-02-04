$localDirectory = "C:\Users\Default\Downloads"
Set-Location -Path $localDirectory

$fileName = "EpicInstaller-10.19.2-enterprise"
$fileUrl = "https://usawest.blob.core.windows.net/bin/Epic/EpicInstaller-10.19.2-enterprise.msi"
Invoke-WebRequest -OutFile "$fileName.msi" -Uri $fileUrl

msiexec /i "$fileName.msi" /quiet /qn /norestart /log "$fileName.log"
