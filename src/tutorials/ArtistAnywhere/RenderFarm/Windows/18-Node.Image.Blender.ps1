Set-Location -Path "C:\Users\Default\Downloads"

$downloadUrl = "https://bit.blob.core.windows.net/bin/Blender"

$fileName = "blender-2.91.2-windows64.msi"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

msiexec /i $fileName /quiet /qn /norestart /log $fileName.Replace(".msi", ".log")
