DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default -Name AnonymousUid -PropertyType DWord -Value 0
New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default -Name AnonymousGid -PropertyType DWord -Value 0
net stop nfsclnt
net stop nfsrdr
net start nfsrdr
net start nfsclnt

Set-Location -Path 'C:\Users\Public\Downloads'
