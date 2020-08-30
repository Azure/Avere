$localDirectory = '/Users/Public/Downloads/OpenCue'
New-Item -ItemType 'Directory' -Path $localDirectory -Force
Set-Location -Path $localDirectory

$storageDirectory = 'T:/OpenCue/v0.4.55'
New-Item -ItemType 'Directory' -Path $storageDirectory -Force

$fileName = 'opencue-requirements.txt'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements.txt'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .

$fileName = 'opencue-requirements-gui.txt'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://raw.githubusercontent.com/AcademySoftwareFoundation/OpenCue/master/requirements_gui.txt'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .

$fileName = 'opencue-pycue.tar.gz'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/pycue-0.4.55-all.tar.gz'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .
tar -xzf $fileName

$fileName = 'opencue-pyoutline.tar.gz'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/pyoutline-0.4.55-all.tar.gz'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .
tar -xzf $fileName

$fileName = 'opencue-rqd.tar.gz'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/rqd-0.4.55-all.tar.gz'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .
tar -xzf $fileName

$fileName = 'opencue-admin.tar.gz'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/cueadmin-0.4.55-all.tar.gz'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .
tar -xzf $fileName

$fileName = 'opencue-submit.tar.gz'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/cuesubmit-0.4.55-all.tar.gz'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .
tar -xzf $fileName

$fileName = 'opencue-gui.tar.gz'
$fileExists = Test-Path -PathType 'Leaf' -Path $storageDirectory/$fileName
if (!$fileExists) {
    Invoke-WebRequest -OutFile $storageDirectory/$fileName -Uri 'https://github.com/AcademySoftwareFoundation/OpenCue/releases/download/v0.4.55/cuegui-0.4.55-all.tar.gz'
}
Copy-Item -Path $storageDirectory/$fileName -Destination .
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
