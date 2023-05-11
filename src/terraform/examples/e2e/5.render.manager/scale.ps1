param (
  [string] $renderManager,
  [string] $resourceGroupName,
  [string] $scaleSetName,
  [int] $scaleSetMachineCountMax
  [int] $jobWaitThresholdSeconds
  [int] $workerIdleDeleteSeconds
)

$ErrorActionPreference = "Stop"

az login --identity

$queuedTasks = 0
if ("$renderManager" -like "*Deadline*") {
  $activeJobIds = deadlinecommand -GetJobIdsFilter Status=Active
  foreach ($jobId in $activeJobIds) {
    $jobDetails = deadlinecommand -GetJobDetails $jobId
    $jobWaitEndTime = Get-Date -AsUtc
    $jobWaitSeconds = (New-TimeSpan -Start $jobDetails.SubmitDate -End $jobWaitEndTime).TotalSeconds
    if ($jobWaitSeconds -gt $jobWaitThresholdSeconds) {
      $taskIds = deadlinecommand -GetJobTaskIds $jobId
      foreach ($taskId in $taskIds) {
        $task = deadlinecommand -GetJobTask $jobId $taskId | ConvertFrom-StringData
        if ($task.TaskStatus -eq "Queued") {
          $queuedTasks++
        }
      }
    }
  }
}

if ($queuedTasks -gt 0) { # Scale Up
  $scaleSetNodeCount = az vmss show --resource-group $resourceGroupName --name $scaleSetName --query "sku.capacity"
  if ($scaleSetMachineCountMax -ge 1 -and $scaleSetNodeCount + $queuedTasks -gt $scaleSetMachineCountMax) {
    $scaleSetNodeCount = $scaleSetMachineCountMax
  } else {
    $scaleSetNodeCount += $queuedTasks
  }
  az vmss scale --resource-group $resourceGroupName --name $scaleSetName --new-capacity $scaleSetNodeCount
} else { # Scale Down
  if ("$renderManager" -like "*Deadline*") {
    $workerNames = deadlinecommand -GetSlaveNames
    foreach ($workerName in $workerNames) {
      $worker = deadlinecommand -GetSlave $workerName | ConvertFrom-StringData
      if ($worker.SlaveState -eq "Idle") {
        $workerIdleStartTime = $worker.WorkerLastRenderFinishedTime == "" ? $worker.StateDateTime : $worker.WorkerLastRenderFinishedTime
        $workerIdleEndTime = Get-Date -AsUtc
        $workerIdleSeconds = (New-TimeSpan -Start $workerIdleStartTime -End $workerIdleEndTime).TotalSeconds
        if ($workerIdleSeconds -gt $workerIdleDeleteSeconds) {
          $instanceId = az vmss list-instances --resource-group $resourceGroupName --name $scaleSetName --query "[?osProfile.computerName=='$workerName'].instanceId" --output tsv
          az vmss delete-instances --resource-group $resourceGroupName --name $scaleSetName --instance-ids $instanceId
        }
      }
    }
  }
}
