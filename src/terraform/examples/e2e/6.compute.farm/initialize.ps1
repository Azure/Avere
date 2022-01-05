$mountFile = "C:\Windows\Temp\mount.bat"
New-Item -Path $mountFile -ItemType File
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }
Add-Content -Path $mountFile -Value "net stop Deadline10LauncherService"
Add-Content -Path $mountFile -Value "net start Deadline10LauncherService"

$taskName = "AAA Storage Mounts"
$taskAction = New-ScheduledTaskAction -Execute $mountFile
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System
Start-Process -FilePath $mountFile -Wait

$customDataInput = "C:\AzureData\CustomData.bin"
$customDataOutput = "C:\AzureData\Terminate.ps1"
$fileStream = New-Object System.IO.FileStream($customDataInput, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$gZipStream = New-Object System.IO.Compression.GZipStream($fileStream, [System.IO.Compression.CompressionMode]::Decompress)
$streamReader = New-Object System.IO.StreamReader($gZipStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $customDataOutput

$nextMinute = (Get-Date).Minute + 1
for ($i = 0; $i -lt 12; $i++) {
  $taskName = "AAA Event Handler $i"
  $taskInterval = New-TimeSpan -Minutes 1
  $taskStart = Get-Date -Minute $nextMinute -Second ($i * 5)
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "-ExecutionPolicy Unrestricted -File $customDataOutput"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System
}
