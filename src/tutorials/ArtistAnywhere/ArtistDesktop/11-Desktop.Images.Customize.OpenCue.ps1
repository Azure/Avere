Set-Location -Path 'C:\Users\Public\Downloads'

$fileName = 'opencue-requirements.txt'
$fileUrl = 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements.txt'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName

$fileName = 'opencue-requirements-gui.txt'
$fileUrl = 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements_gui.txt'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName

$fileName = 'opencue-pycue.tar.gz'
$fileUrl = 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/pycue-0.4.14-all.tar.gz'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName
tar -xzf $fileName

$fileName = 'opencue-pyoutline.tar.gz'
$fileUrl = 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/pyoutline-0.4.14-all.tar.gz'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName
tar -xzf $fileName

$fileName = 'opencue-rqd.tar.gz'
$fileUrl = 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/rqd-0.4.14-all.tar.gz'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName
tar -xzf $fileName

$fileName = 'opencue-admin.tar.gz'
$fileUrl = 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cueadmin-0.4.14-all.tar.gz'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName
tar -xzf $fileName

$fileName = 'opencue-submit.tar.gz'
$fileUrl = 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuesubmit-0.4.14-all.tar.gz'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName
tar -xzf $fileName

$fileName = 'opencue-gui.tar.gz'
$fileUrl = 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/0.4.14/cuegui-0.4.14-all.tar.gz'
Invoke-WebRequest -Uri $fileUrl -OutFile $fileName
# tar -xzf $fileName

# pip3 install -r 'opencue-requirements.txt'
# pip3 install -r 'opencue-requirements-gui.txt'

# Set-Location -Path 'pycue-*'
# python3 setup.py install
# Set-Location -Path '../pyoutline-*'
# python3 setup.py install
# Set-Location -Path '../rqd-*'
# python3 setup.py install
# Set-Location -Path '../cueadmin-*'
# python3 setup.py install
# Set-Location -Path '../cuesubmit-*'
# python3 setup.py install
# Set-Location -Path '../cuegui-*'
# python3 setup.py install
