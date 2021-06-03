Set-Location -Path "C:\Users\Public\Downloads"

DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
$registryKeyPath = "HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default"
New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0

$localDirectoryPath = "/mnt/storage"
$storageAccountName = "hpc02"
$storageContainerName = "show"

mkdir -p $localDirectoryPath
mount -o sec=sys,vers=3,nolock,proto=tcp $storageAccountName.blob.core.windows.net:/$storageAccountName/$storageContainerName $localDirectoryPath

$fileName = "https://download.blender.org/demo/cycles/lone-monk_cycles_and_exposure-node_demo.blend"
Invoke-WebRequest -OutFile $fileName -Uri $localDirectoryPath/$fileName
