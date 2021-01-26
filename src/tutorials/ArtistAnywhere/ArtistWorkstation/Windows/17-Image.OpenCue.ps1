$directoryName = "OpenCue"
$localDirectory = "C:\Users\Public\Downloads\$directoryName"

New-Item -ItemType "Directory" -Path $localDirectory
Set-Location -Path $localDirectory

$downloadUrl = "https://usawest.blob.core.windows.net/bin/Python"

$fileName = "python-3.7.9-amd64.exe"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

Start-Process -FilePath $fileName -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

$downloadUrl = "https://usawest.blob.core.windows.net/bin/OpenCue/v0.4.95"

$fileName = "opencue-requirements.txt"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

$fileName = "opencue-requirements-gui.txt"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName

$fileName = "opencue-pycue.tar.gz"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
tar -xzf $fileName

$fileName = "opencue-pyoutline.tar.gz"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
tar -xzf $fileName

$fileName = "opencue-admin.tar.gz"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
tar -xzf $fileName

$fileName = "opencue-submit.tar.gz"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
tar -xzf $fileName

$fileName = "opencue-gui.tar.gz"
Invoke-WebRequest -OutFile $fileName -Uri $downloadUrl/$fileName
# tar -xzf $fileName

pip install --upgrade pip
pip install --requirement "opencue-requirements.txt"
pip install --requirement "opencue-requirements-gui.txt"

Set-Location -Path "pycue-*"
python setup.py install
Set-Location -Path ""../pyoutline-*"
python setup.py install
Set-Location -Path "../cueadmin-*"
python setup.py install
Set-Location -Path ""../cuesubmit-*"
python setup.py install
# Set-Location -Path "../cuegui-*"
# python setup.py install
