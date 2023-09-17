$fileSystemMountPath = "C:\AzureData\fileSystemMount.bat"

function StartProcess ($filePath, $argumentList, $logFile) {
  if ($logFile -eq $null) {
    if ($argumentList -eq $null) {
      Start-Process -FilePath $filePath -Wait
    } else {
      Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait
    }
  } else {
    if ($argumentList -eq $null) {
      Start-Process -FilePath $filePath -Wait -RedirectStandardOutput $logFile-out -RedirectStandardError $logFile-err
    } else {
      Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait -RedirectStandardOutput $logFile-out -RedirectStandardError $logFile-err
    }
    Get-Content -Path $logFile-err | Write-Host
  }
}

function FileExists ($filePath) {
  return Test-Path -PathType Leaf -Path $filePath
}

function SetFileSystemMount ($fileSystemMount) {
  if (!(FileExists $fileSystemMountPath)) {
    New-Item -ItemType File -Path $fileSystemMountPath
  }
  $mountScript = Get-Content -Path $fileSystemMountPath
  if ($mountScript -eq $null -or $mountScript -notlike "*$fileSystemMount*") {
    Add-Content -Path $fileSystemMountPath -Value $fileSystemMount
  }
}

function RegisterFileSystemMountPath ($binDirectory) {
  if (FileExists $fileSystemMountPath) {
    StartProcess $fileSystemMountPath $null "$binDirectory\file-system-mount"
    $taskName = "AAA File System Mount"
    $taskAction = New-ScheduledTaskAction -Execute $fileSystemMountPath
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
  }
}

function EnableFarmClient () {
  deadlinecommand.exe -ChangeRepository Direct S:\ S:\Deadline10Client.pfx ""
}

function JoinActiveDirectory ($domainName, $serverName, $adminUsername, $adminPassword) {
  if ($domainName -ne "") {
    $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
    $adminCredential = New-Object System.Management.Automation.PSCredential("$adminUsername@$domainName", $securePassword)
    $adComputer = Get-ADComputer -Identity $(hostname) -Server $serverName -Credential $adminCredential -ErrorAction SilentlyContinue
    if ($adComputer -ne $null) {
      Remove-ADObject -Identity $adComputer -Recursive -Confirm:$false
    }
    Add-Computer -DomainName $domainName -Server $serverName -Credential $adminCredential -Force -PassThru -Verbose
  }
}
