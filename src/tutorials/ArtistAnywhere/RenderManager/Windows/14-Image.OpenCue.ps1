Set-Location -Path "C:\Users\Default\Downloads"

$downloadUrl = "https://bit.blob.core.windows.net/bin/OpenCue"

$fileName = "OpenCue-v0.4.95.zip"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
Expand-Archive -Path $fileName

Set-Location -Path "OpenCue*"
