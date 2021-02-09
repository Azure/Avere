Set-Location -Path "C:\Users\Default\Downloads"

$downloadUrl = "https://bit.blob.core.windows.net/bin/Graphics"

$fileName = "AMD-Azure-NVv4-Driver-20Q1-Hotfix3.exe"
#$fileName = "452.57_grid_win10_server2016_server2019_64bit_international.exe"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

#Start-Process -FilePath $fileName -ArgumentList "/s" -Wait
