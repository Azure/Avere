$fileSystemMountPath = "C:\AzureData\fileSystemMount.bat"

function StartProcess ($filePath, $argumentList, $logFile) {
  if ($logFile) {
    if ($argumentList) {
      Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait -RedirectStandardOutput $logFile-out -RedirectStandardError $logFile-err
    } else {
      Start-Process -FilePath $filePath -Wait -RedirectStandardOutput $logFile-out -RedirectStandardError $logFile-err
    }
    Get-Content -Path $logFile-err | Write-Host
  } else {
    if ($argumentList) {
      Start-Process -FilePath $filePath -ArgumentList $argumentList -Wait
    } else {
      Start-Process -FilePath $filePath -Wait
    }
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

function JoinActiveDirectory ($domainName, $serverName, $orgUnitPath, $adminUsername, $adminPassword) {
  if ($adminUsername -notlike "*@*") {
    $adminUsername = "$adminUsername@$domainName"
  }
  $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
  $adminCredential = New-Object System.Management.Automation.PSCredential($adminUsername, $securePassword)

  $adComputer = Get-ADComputer -Identity $(hostname) -Server $serverName -Credential $adminCredential -ErrorAction SilentlyContinue
  if ($adComputer) {
    Remove-ADObject -Identity $adComputer -Recursive -Confirm:$false
    Start-Sleep -Seconds 5
  }

  if ($orgUnitPath -ne "") {
    Add-Computer -DomainName $domainName -Server $serverName -Credential $adminCredential -OUPath $orgUnitPath -Force -PassThru -Verbose -Restart
  } else {
    Add-Computer -DomainName $domainName -Server $serverName -Credential $adminCredential -Force -PassThru -Verbose -Restart
  }
}

function Retry ($delaySeconds, $maxCount, $scriptBlock) {
  $count = 0
  $exception = $null
  do {
    $count++
    try {
      $scriptBlock.Invoke()
      $exception = $null
      exit
    } catch {
      $exception = $_.Exception
      Start-Sleep -Seconds $delaySeconds
    }
  } while ($count -lt $maxCount)
  if ($exception) {
    throw $exception
  }
}
