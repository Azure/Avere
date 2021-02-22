Set-Location -Path "C:\Users\Default\Downloads"

$processorInfo = Get-ComputerInfo | Select-Object -ExpandProperty "CsProcessors"
if ($processorInfo.Contains("AMD")) {
    $fileName = "AMD-Azure-NVv4-Driver-20Q1-Hotfix3.exe"
} else {
    $fileName = "461.09_grid_win10_server2016_server2019_64bit_azure_swl.exe"
}
$downloadUrl = "https://bit.blob.core.windows.net/bin/Graphics/Windows"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
