$localDirectory = '/Users/Public/Downloads/Blender'
New-Item -ItemType 'Directory' -Path $localDirectory -Force
Set-Location -Path $localDirectory

$storageDirectory = 'T:/Blender'
New-Item -ItemType 'Directory' -Path $storageDirectory -Force

$fileName = 'blender2834.msi'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://mirror.clarkson.edu/blender/release/Blender2.83/blender-2.83.4-windows64.msi'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .

Start-Process -FilePath $fileName -ArgumentList '/quiet' -Wait
$oldPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
$newPath = "$oldPath;C:\Program Files\Blender Foundation\Blender 2.83"
[System.Environment]::SetEnvironmentVariable('PATH', $newPath, [System.EnvironmentVariableTarget]::Machine)
