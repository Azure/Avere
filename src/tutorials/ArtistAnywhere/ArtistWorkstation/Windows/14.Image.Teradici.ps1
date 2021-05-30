Set-Location -Path "C:\Users\Public\Downloads"

$fileName = "pcoip-agent-graphics_21.03.3.exe"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Teradici"
Invoke-WebRequest -OutFile $fileName -Uri "$containerUrl/$fileName?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"
