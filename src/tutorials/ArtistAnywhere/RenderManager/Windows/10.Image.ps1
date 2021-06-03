Set-Location -Path "C:\Users\Public\Downloads"

$sasParameters = "?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"

$containerUrl = "https://bit1.blob.core.windows.net/bin/PostgreSQL"

$fileName = "VC_redist.x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName$sasParameters
Start-Process -FilePath $fileName -ArgumentList "/s" -Wait

$fileName = "postgresql-12.6-1-windows-x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "--mode unattended --unattendedmodeui none --enable-components commandlinetools --disable-components server,pgAdmin,stackbuilder" -Wait

$fileName = "jdk-11.0.10_windows-x64_bin.exe"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Java"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName$sasParameters
Start-Process -FilePath $fileName -ArgumentList "/s" -Wait

$containerUrl = "https://bit1.blob.core.windows.net/bin/WinSW"

$fileName = "WinSW-x64.xml"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName$sasParameters

$fileName = "WinSW-x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName$sasParameters
Start-Process -FilePath $fileName -ArgumentList "install" -Wait

$fileName = "OpenCue-v0.8.8.zip"
$containerUrl = "https://bit1.blob.core.windows.net/bin/OpenCue"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName$sasParameters
Expand-Archive -Path $fileName

Set-Location -Path "OpenCue-*"
Copy-Item -Path "opencue-bot.jar" -Destination ".."
