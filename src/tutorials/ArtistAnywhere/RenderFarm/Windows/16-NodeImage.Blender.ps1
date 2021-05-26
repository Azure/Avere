Set-Location -Path "C:\Users\Public\Downloads"

$fileName = "blender-2.92.0-windows64.msi"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Blender"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
msiexec /i $fileName /quiet /qn /norestart /log $fileName.Replace(".msi", ".log")
