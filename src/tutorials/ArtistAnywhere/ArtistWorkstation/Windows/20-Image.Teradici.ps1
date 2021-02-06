Set-Location -Path "C:\Users\Default\Downloads"

$downloadUrl = "https://bit.blob.core.windows.net/bin/Teradici"

$fileName = "pcoip-agent-graphics_21.01.1.exe"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
