Set-Location -Path "C:\Users\Public\Downloads"

# DISM /Online /Enable-Feature /FeatureName:ClientForNFS-Infrastructure /All
# $registryKeyPath = "HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default"
# New-ItemProperty -Path $registryKeyPath -Name AnonymousUid -PropertyType DWORD -Value 0
# New-ItemProperty -Path $registryKeyPath -Name AnonymousGid -PropertyType DWORD -Value 0
