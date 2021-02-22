Set-Location -Path "C:\Users\Default\Downloads"

$fileName = "jdk-11.0.10_windows-x64_bin.exe"
$javaPath = "C:\Program Files\Java\jdk-11.0.10\bin"
$downloadUrl = "https://bit.blob.core.windows.net/bin/Java"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "/s" -Wait

$fileName = "OpenCue-v0.8.8.zip"
$downloadUrl = "https://bit.blob.core.windows.net/bin/OpenCue"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
Expand-Archive -Path $fileName

Set-Location -Path "OpenCue*"
