Set-Location -Path "C:\Users\Public\Downloads"

$sasParameters = "?sv=2020-04-08&st=2021-05-16T17%3A37%3A25Z&se=2222-05-17T17%3A37%3A00Z&sr=c&sp=rl&sig=jY6xDzLXfDogsXIAfwNMd5hCu%2BcR8Tg1rgJZreBFJj4%3D"

$fileName = "python-3.7.9-amd64.exe"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Python"
Invoke-WebRequest -OutFile $fileName -Uri "$containerUrl/$fileName$sasParameters"
Start-Process -FilePath $fileName -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

$fileName = "OpenCue-v0.8.8.zip"
$containerUrl = "https://bit1.blob.core.windows.net/bin/OpenCue"
Invoke-WebRequest -OutFile $fileName -Uri "$containerUrl/$fileName$sasParameters"
Expand-Archive -Path $fileName

Set-Location -Path "OpenCue*/cuegui-*"
pip install --requirement "requirements.txt" --ignore-installed
pip install --requirement "requirements_gui.txt"

Set-Location -Path "../pycue-*"
python setup.py install
Set-Location -Path "../pyoutline-*"
python setup.py install
Set-Location -Path "../cueadmin-*"
python setup.py install
Set-Location -Path "../cuesubmit-*"
python setup.py install
Set-Location -Path "../cuegui-*"
python setup.py install
