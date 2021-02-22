Set-Location -Path "C:\Users\Default\Downloads"

$fileName = "blender-2.91.2-windows64.msi"
$downloadUrl = "https://bit.blob.core.windows.net/bin/Blender"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
msiexec /i $fileName /quiet /qn /norestart /log $fileName.Replace(".msi", ".log")
