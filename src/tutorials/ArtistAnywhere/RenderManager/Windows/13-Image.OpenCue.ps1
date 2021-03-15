Set-Location -Path "C:\Users\Public\Downloads"

$containerUrl = "https://bit1.blob.core.windows.net/bin/PostgreSQL"

$fileName = "VC_redist.x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "/s" -Wait

$fileName = "postgresql-12.6-1-windows-x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "--mode unattended --unattendedmodeui none --enable-components commandlinetools --disable-components server,pgAdmin,stackbuilder" -Wait

$fileName = "jdk-11.0.10_windows-x64_bin.exe"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Java"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "/s" -Wait

$fileName = "OpenCue-v0.8.8.zip"
$containerUrl = "https://bit1.blob.core.windows.net/bin/OpenCue"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
Expand-Archive -Path $fileName
