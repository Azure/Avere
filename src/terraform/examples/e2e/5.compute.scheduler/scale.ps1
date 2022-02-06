az login --identity

$queuedTasks = 0
$activeJobIds = deadlinecommand -GetJobIdsFilter Status=Active
foreach ($jobId in $activeJobIds) {
  $taskIds = deadlinecommand -GetJobTaskIds $jobId
  foreach ($taskId in $taskIds) {
    $task = deadlinecommand -GetJobTask $jobId $taskId | ConvertFrom-StringData
    if ($task.TaskStatus -eq "Queued") {
      $queuedTasks++
    }
  }
}

if ($queuedTasks -gt 0) {
  az vmss scale --resource-group $resourceGroupName --name $scaleSetName --new-capacity $queuedTasks 
} else {
  $workerNames = deadlinecommand -GetSlaveNames
  foreach ($workerName in $workerNames) {
    $worker = deadlinecommand -GetSlave $workerName | ConvertFrom-StringData
    if ($worker.SlaveState -eq "Idle") {
      $workerIdleStartTime = $worker.WorkerLastRenderFinishedTime == "" ? $worker.StateDateTime : $worker.WorkerLastRenderFinishedTime
      $workerIdleEndTime = Get-Date -AsUtc
      $workerIdleSeconds = (New-TimeSpan -Start $workerIdleStartTime -End $workerIdleEndTime).TotalSeconds
      if ($workerIdleSeconds -gt $workerIdleSecondsDelete) {
        $instanceId = az vmss list-instances --resource-group $resourceGroupName --name $scaleSetName --query "[?osProfile.computerName=='$workerName'].instanceId" --output tsv
        az vmss delete-instances --resource-group $resourceGroupName --name $scaleSetName --instance-ids $instanceId
      }
    }
  }
}