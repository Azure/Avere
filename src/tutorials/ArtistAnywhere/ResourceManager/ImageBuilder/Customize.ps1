param (
    [string] $gpuDriverUrl = "https://bit1.blob.core.windows.net/bin/Graphics/Windows",
    [string] $gpuDriverNVIDIA = "461.09_grid_win10_server2016_server2019_64bit_azure_swl.exe",
    [string] $gpuDriverAMD = "AMD-Azure-NVv4-Driver-20Q4.exe"
)

Set-Location -Path "C:\Users\Public\Downloads"

$processorInfo = Get-ComputerInfo | Select-Object -ExpandProperty "CsProcessors"
if ($processorInfo.Manufacturer.Contains("AMD")) {
    $gpuDriver = $gpuDriverAMD
} else {
    $gpuDriver = $gpuDriverNVIDIA
}
Invoke-WebRequest -OutFile $gpuDriver -Uri $gpuDriverUrl/$gpuDriver
Start-Process -FilePath $gpuDriver -ArgumentList "/s /noreboot" -Wait
