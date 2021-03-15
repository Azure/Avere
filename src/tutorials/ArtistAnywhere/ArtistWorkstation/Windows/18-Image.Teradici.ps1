Set-Location -Path "C:\Users\Public\Downloads"

$fileName = "pcoip-agent-graphics_21.01.4.exe"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Teradici"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
