function AddFileSystemMounts ($binDirectory, $fsMountsDelimiter, $fsMounts) {
  Write-Host $binDirectory
  Write-Host $fsMountsDelimiter
  Write-Host $fsMounts
  $fsMountsFile = "$binDirectory\fs-mounts.bat"
  if (!Test-Path -Path $fsMountsFile) {
    New-Item -ItemType File -Path $fsMountsFile
  }
  foreach ($fsMount in $fsMounts.Split($fsMountsDelimiter)) {
    Add-Content -Path $fsMountsFile -Value $fsMount
  }
  return $fsMountsFile
}

function RegisterFileSystemMounts ($fsMountsFile) {
  $fsMountsFileSize = (Get-Item -Path $fsMountsFile).Length
  if ($fsMountsFileSize -gt 0) {
    $taskName = "AAA File System Mounts"
    $taskAction = New-ScheduledTaskAction -Execute $fsMountsFile
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -AsJob -User System -Force
    Start-Process -FilePath $fsMountsFile -Wait -RedirectStandardOutput "fs-mounts.output.txt" -RedirectStandardError "fs-mounts.error.txt"
  }
}
