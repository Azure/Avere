$mountFile = "C:\Windows\Temp\mounts.bat"
New-Item -Path $mountFile -ItemType File
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $mountFile -Value "${fsMount}"
%{ endfor }

$taskName = "AAA Storage Mounts"
$taskAction = New-ScheduledTaskAction -Execute $mountFile
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System
Start-Process -FilePath $mountFile -Wait -RedirectStandardError $mountFile.Replace(".bat", "-error.txt") -RedirectStandardOutput $mountFile.Replace(".bat", "-output.txt")

$databaseFile = "C:\Windows\Temp\database.ps1"
New-Item -Path $databaseFile -ItemType File
Add-Content -Path $databaseFile -Value '$serviceName = "Deadline10DatabaseService"'
Add-Content -Path $databaseFile -Value '$serviceStatus = (Get-Service -Name $serviceName).Status'
Add-Content -Path $databaseFile -Value 'if ($serviceStatus -ne "Running") { Start-Service -Name $serviceName }'

$taskName = "AAA Scheduler Database"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Minutes 5
$taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "-ExecutionPolicy Unrestricted -File $databaseFile"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System

$databaseHost = hostname
$databasePort = 27100
$databaseName = "deadline10db"
netsh advfirewall firewall add rule name="Allow Mongo Database" dir=in action=allow protocol=TCP localport=$databasePort
deadlinecommand -UpdateDatabaseSettings C:\DeadlineRepository MongoDB $databaseHost $databaseName $databasePort 0 false false '""' '""' '""' false

$customDataInput = "C:\AzureData\CustomData.bin"
$customDataOutput = "C:\AzureData\Scale.ps1"
$fileStream = New-Object System.IO.FileStream($customDataInput, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$gZipStream = New-Object System.IO.Compression.GZipStream($fileStream, [System.IO.Compression.CompressionMode]::Decompress)
$streamReader = New-Object System.IO.StreamReader($gZipStream)
Out-File -InputObject $streamReader.ReadToEnd() -FilePath $customDataOutput

$taskName = "AAA Render Farm Scaler"
$taskStart = Get-Date
$taskInterval = New-TimeSpan -Minutes 1
$taskAction = New-ScheduledTaskAction -Execute "PowerShell" -Argument "-ExecutionPolicy Unrestricted -File $customDataOutput -resourceGroupName ${autoScale.resourceGroupName} -scaleSetName ${autoScale.scaleSetName}"
$taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval $taskInterval -At $taskStart -Once
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System

if (${autoScale.enable} -ne "true") {
  Disable-ScheduledTask -TaskName $taskName
}

