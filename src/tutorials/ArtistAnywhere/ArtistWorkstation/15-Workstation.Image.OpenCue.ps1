$directoryName = 'OpenCue'
$localDirectory = "C:\Users\Public\Downloads\$directoryName"

New-Item -ItemType 'Directory' -Path $localDirectory
Set-Location -Path $localDirectory

$downloadUrl = 'https://mediasolutions.blob.core.windows.net/bin/Python'

$fileName = 'python-3.7.9-amd64.exe'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl

Start-Process -FilePath $fileName -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait

$downloadUrl = 'https://mediasolutions.blob.core.windows.net/bin/OpenCue/v0.4.95'

$fileName = 'opencue-requirements.txt'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl

$fileName = 'opencue-requirements-gui.txt'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl

$fileName = 'opencue-pycue.tar.gz'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl
tar -xzf $fileName

$fileName = 'opencue-pyoutline.tar.gz'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl
tar -xzf $fileName

$fileName = 'opencue-admin.tar.gz'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl
tar -xzf $fileName

$fileName = 'opencue-submit.tar.gz'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl
tar -xzf $fileName

$fileName = 'opencue-gui.tar.gz'
$fileUrl = "$downloadUrl/$fileName"
Invoke-WebRequest -OutFile $fileName -Uri $fileUrl
# tar -xzf $fileName

pip install --upgrade pip
pip install --requirement 'opencue-requirements.txt'
pip install --requirement 'opencue-requirements-gui.txt'

Set-Location -Path 'pycue-*'
python setup.py install
Set-Location -Path '../pyoutline-*'
python setup.py install
Set-Location -Path '../cueadmin-*'
python setup.py install
Set-Location -Path '../cuesubmit-*'
python setup.py install
# Set-Location -Path '../cuegui-*'
# python setup.py install
