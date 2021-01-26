$directoryName = "Teradici"
$localDirectory = "C:\Users\Public\Downloads\$directoryName"

New-Item -ItemType "Directory" -Path $localDirectory
Set-Location -Path $localDirectory

$fileName = "Teradici-Graphics-Agent-20102.exe"
$fileUrl = "https://usawest.blob.core.windows.net/bin/Teradici/pcoip-agent-graphics_20.10.2.exe"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl
