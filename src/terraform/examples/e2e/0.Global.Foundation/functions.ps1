$fileSystemMountPath = "C:\AzureData\fileSystemMount.bat"

function InitializeClient ($binDirectory, $activeDirectoryJson) {
  StartProcess deadlinecommand.exe "-ChangeRepository Direct S:\ S:\Deadline10Client.pfx" "$binDirectory\deadline-repository"
  $activeDirectory = ConvertFrom-Json -InputObject $activeDirectoryJson
  if ($activeDirectory.enable) {
    Retry 5 10 {
      JoinActiveDirectory $activeDirectory.domainName $activeDirectory.domainServerName $activeDirectory.orgUnitPath $activeDirectory.adminUsername $activeDirectory.adminPassword
    }
  }
}

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

function SetFileSystems ($binDirectory, $fileSystemsJson) {
  $fileSystems = ConvertFrom-Json -InputObject $fileSystemsJson
  foreach ($fileSystem in $fileSystems) {
    if ($fileSystem.enable) {
      SetFileSystemMounts $fileSystem.mounts
    }
  }
  RegisterFileSystemMounts $binDirectory
}

function SetFileSystemMounts ($fileSystemMounts) {
  if (!(FileExists $fileSystemMountPath)) {
    New-Item -ItemType File -Path $fileSystemMountPath
  }
  $mountScript = Get-Content -Path $fileSystemMountPath
  foreach ($fileSystemMount in $fileSystemMounts) {
    if ($mountScript -eq $null -or $mountScript -notlike "*$fileSystemMount*") {
      Add-Content -Path $fileSystemMountPath -Value $fileSystemMount
    }
  }
}

function RegisterFileSystemMounts ($binDirectory) {
  if (FileExists $fileSystemMountPath) {
    StartProcess $fileSystemMountPath $null "$binDirectory\file-system-mount"
    $taskName = "AAA File System Mount"
    $taskAction = New-ScheduledTaskAction -Execute $fileSystemMountPath
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User System -Force
  }
}

function JoinActiveDirectory ($domainName, $domainServerName, $orgUnitPath, $adminUsername, $adminPassword) {
  if ($adminUsername -notlike "*@*") {
    $adminUsername = "$adminUsername@$domainName"
  }
  $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
  $adminCredential = New-Object System.Management.Automation.PSCredential($adminUsername, $securePassword)

  try {
    $localComputerName = $(hostname)
    $adComputer = Get-ADComputer -Identity $localComputerName -Server $domainServerName -Credential $adminCredential
    Remove-ADObject -Identity $adComputer -Server $domainServerName -Recursive -Confirm:$false
    Start-Sleep -Seconds 5
    $adComputer = null
  } catch {
    if ($adComputer) {
      Write-Error "Error occurred while trying to remove the $localComputerName computer AD object."
    }
  }

  if ($orgUnitPath -ne "") {
    Add-Computer -DomainName $domainName -Server $domainServerName -Credential $adminCredential -OUPath $orgUnitPath -Force -PassThru -Verbose -Restart
  } else {
    Add-Computer -DomainName $domainName -Server $domainServerName -Credential $adminCredential -Force -PassThru -Verbose -Restart
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
