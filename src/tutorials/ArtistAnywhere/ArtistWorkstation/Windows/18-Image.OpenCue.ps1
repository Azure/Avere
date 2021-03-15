Set-Location -Path "C:\Users\Public\Downloads"

$fileName = "python-3.7.9-amd64.exe"
$containerUrl = "https://bit1.blob.core.windows.net/bin/Python"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
Start-Process -FilePath $fileName -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

$fileName = "OpenCue-v0.8.8.zip"
$containerUrl = "https://bit1.blob.core.windows.net/bin/OpenCue"
Invoke-WebRequest -OutFile $fileName -Uri $containerUrl/$fileName
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
