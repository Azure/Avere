DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default -Name AnonymousUid -PropertyType DWord -Value 0
New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default -Name AnonymousGid -PropertyType DWord -Value 0
net stop nfsclnt
net stop nfsrdr
net start nfsrdr
net start nfsclnt

$localDrive = 'T'
New-PSDrive -Name $localDrive -PSProvider 'FileSystem' -Root '\\10.0.194.4\tools' -Scope Global -Persist

$localDirectory = '/Users/Public/Downloads'
Set-Location -Path $localDirectory

$storageDirectory = $localDrive + ':/Python'
New-Item -ItemType 'Directory' -Path $storageDirectory -Force

$fileName = 'python385.exe'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://www.python.org/ftp/python/3.8.5/python-3.8.5-amd64.exe'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .

Start-Process -FilePath $fileName -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait

$storageDirectory = $localDrive + ':/VisualStudio'
New-Item -ItemType 'Directory' -Path $storageDirectory -Force

$fileName = 'vsBuildTools16.exe'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://aka.ms/vs/16/release/vs_buildtools.exe'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .

Start-Process -FilePath $fileName -ArgumentList '--quiet --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended' -Wait
$oldPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
$newPath = "$oldPath;C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools"
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, [System.EnvironmentVariableTarget]::Machine)
