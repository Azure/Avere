$fsMountPath = "$env:AllUsersProfile\Microsoft\Windows\Start Menu\Programs\StartUp\FSMount.bat"
New-Item -Path $fsMountPath -ItemType File
%{ for fsMount in fileSystemMounts }
  Add-Content -Path $fsMountPath -Value "${fsMount}"
%{ endfor }
Start-Process -FilePath $fsMountPath -Wait

$hostName = hostname
$databasePort = 27100
$databaseName = "deadline10db"

Set-Location -Path "C:\Program Files\Thinkbox\Deadline10\bin"
./deadlinecommand -ConfigureDatabase $hostName $databasePort $databaseName false '""' '""' false ${userName} "pass:${userPassword}" '""' false
./deadlinecommand -UpdateDatabaseSettings "C:\DeadlineRepository" "MongoDB" $hostName $databaseName $databasePort 0 false false ${userName} "pass:${userPassword}" '""' false
./deadlinecommand -ChangeRepository "Direct" "S:\" '""' '""'
