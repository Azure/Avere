Set-Location -Path "C:\Users\Default\Downloads"

$fileName = "pcoip-agent-graphics_21.01.1.exe"
$downloadUrl = "https://bit.blob.core.windows.net/bin/Teradici"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
