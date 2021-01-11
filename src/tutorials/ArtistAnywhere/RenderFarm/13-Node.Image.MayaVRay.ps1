Set-Location -Path "C:\Users\Public\Downloads"

$downloadUrl = "https://mediasolutions.blob.core.windows.net/bin/Autodesk"

$fileName = "Maya2020-1.zip"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
Expand-Archive -Path $fileName

$directoryName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
Start-Process -FilePath "$directoryName\Setup.exe" -ArgumentList "--silent" -Wait

$localPath = "C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\Current\helper"
Start-Process -FilePath "$localPath/AdskLicensingInstHelper.exe" -ArgumentList "change -pk 657L1 -pv 2020.0.0.F" -Wait

$fileName = "AdlmUserSettings.xml"
$localPath = "C:\Users\Default\AppData\Local\Autodesk\Adlm"
New-Item -ItemType "Directory" -Path $localPath
Invoke-WebRequest -OutFile $localPath/$fileName -Uri $downloadUrl/$fileName

$downloadUrl = "https://mediasolutions.blob.core.windows.net/bin/ChaosGroup"

$configFileName = "vray_config.xml"
Invoke-WebRequest -OutFile $configFileName -Uri $downloadUrl/$configFileName

$fileName = "vray_adv_50022_maya2020_x64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

Start-Process -FilePath $fileName -ArgumentList "-gui=0 -quiet=1 -configFile=$configFileName" -Wait
