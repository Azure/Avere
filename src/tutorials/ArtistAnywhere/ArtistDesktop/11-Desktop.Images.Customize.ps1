Set-Location -Path 'C:\Users\Public\Downloads'

$fileName = 'vsBuildTools.exe'
$fileUrl = 'https://aka.ms/vs/16/release/vs_buildtools.exe'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName

Start-Process -FilePath $fileName -ArgumentList '--quiet --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended' -Wait

$oldPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
$newPath = "$oldPath;C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools"
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'Machine')

$fileName = 'python38.exe'
$fileUrl = 'https://www.python.org/ftp/python/3.8.5/python-3.8.5-amd64.exe'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName

Start-Process -FilePath $fileName -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait

DISM /Online /Enable-Feature /All /FeatureName:ClientForNFS-Infrastructure
New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default -Name AnonymousUid -PropertyType DWord -Value 0
New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default -Name AnonymousGid -PropertyType DWord -Value 0
