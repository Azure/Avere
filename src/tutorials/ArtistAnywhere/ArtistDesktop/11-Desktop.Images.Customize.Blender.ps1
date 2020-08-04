Set-Location -Path 'C:\Users\Public\Downloads'

$fileName = 'blender283.msi'
$fileUrl = 'https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.3-windows64.msi'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName

Start-Process -FilePath $fileName -ArgumentList '/quiet' -Wait

$oldPath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
$newPath = "$oldPath;C:\Program Files\Blender Foundation\Blender 2.83"
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'Machine')
