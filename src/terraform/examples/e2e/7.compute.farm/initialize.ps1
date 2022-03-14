$ErrorActionPreference = "Stop"

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
  $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Unrestricted -File $customDataOutput"
  $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force
}

$mountFile = "C:\Windows\Temp\mounts.bat"
New-Item -ItemType File -Path $mountFile
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }

$taskName = "AAA Storage Mounts"
$taskAction = New-ScheduledTaskAction -Execute $mountFile
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force

Start-Process -FilePath $mountFile -Wait -RedirectStandardOutput "$mountFile.output.txt" -RedirectStandardError "$mountFile.error.txt"
