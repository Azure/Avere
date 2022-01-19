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
