Set-Location -Path "C:\Users\Public\Downloads"

$fileName = "blender-2.92.0-windows64.msi"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Blender"
Invoke-WebRequest -OutFile $fileName -Uri "$containerUrl/$fileName?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
msiexec /i $fileName /quiet /qn /norestart /log $fileName.Replace(".msi", ".log")
