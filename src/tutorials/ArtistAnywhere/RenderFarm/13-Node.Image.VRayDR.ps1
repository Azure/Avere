Set-Location -Path "C:\Users\Public\Downloads"

$downloadUrl = "https://mediasolutions.blob.core.windows.net/bin/ChaosGroup"

$fileName = "vray_adv_50022_maya2020_x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

$configFileName = "vray_config_windows.xml"
Invoke-WebRequest -OutFile $configFileName -Uri $downloadUrl/$configFileName

Start-Process -FilePath $fileName -ArgumentList "-gui=0 -quiet=1 -configFile=$configFileName" -Wait
