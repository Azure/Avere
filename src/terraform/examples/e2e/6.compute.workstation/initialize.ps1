param (
  [string] $directoryPath
)

New-Item -Path $directoryPath -ItemType "Directory" -Force
