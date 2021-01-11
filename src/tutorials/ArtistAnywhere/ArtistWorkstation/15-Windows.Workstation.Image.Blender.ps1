$directoryName = "Blender"
$localDirectory = "C:\Users\Public\Downloads\$directoryName"

New-Item -ItemType "Directory" -Path $localDirectory
Set-Location -Path $localDirectory

$fileName = "blender2910"
$fileUrl = "https://mediasolutions.blob.core.windows.net/bin/Blender/blender-2.91.0-windows64.msi"
Invoke-WebRequest -OutFile "$fileName.msi" -Uri $fileUrl

msiexec /i "$fileName.msi" /quiet /qn /norestart /log "$fileName.log"
