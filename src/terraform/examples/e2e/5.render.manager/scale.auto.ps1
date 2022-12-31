param (
  [string] $renderManager,
  [string] $resourceGroupName,
  [string] $scaleSetName,
  [int] $jobWaitThresholdSeconds
)

$ErrorActionPreference = "Stop"

az login --identity

$queuedTasks = 0
$workerIdleDeleteSeconds = 900

if ($renderManager -like "*Qube*") {
  $qbDelimiter = ";"
  $pendingJobs = qbjobs --pending --delimit $qbDelimiter --fields id,reason,timesubmit
  foreach ($pendingJob in $pendingJobs) {
    if (!$pendingJob.StartsWith("total") -and !$pendingJob.StartsWith("id")) {
      $jobReason = $pendingJob.Split($qbDelimiter)[1]
      if ($jobReason -eq "no available hosts to run job.") {
        $jobTimeSubmitStart = $pendingJob.Split($qbDelimiter)[2]
        $jobTimeSubmitEnd = Get-Date -UFormat %s
        $jobWaitSeconds = $jobTimeSubmitEnd - $jobTimeSubmitStart
        if ($jobWaitSeconds -gt $jobWaitThresholdSeconds) {
          $queuedTasks++
        }
      }
    }
  }
}

if ($renderManager -like "*Deadline*") {
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
  $nodeCount = az vmss show --resource-group $resourceGroupName --name $scaleSetName --query "sku.capacity"
  $nodeCount = [int] $nodeCount + $queuedTasks
  az vmss scale --resource-group $resourceGroupName --name $scaleSetName --new-capacity $nodeCount
} else { # Scale Down
  if ($renderManager -like "*Qube*") {
    $qbDelimiter = ";"
    $activeHosts = qbhosts --active --delimit $qbDelimiter
    foreach ($activeHost in $activeHosts) {
      if (!$activeHost.StartsWith("total") -and !$activeHost.StartsWith("name")) {
        $hostName = $activeHost.Split($qbDelimiter)[0]
        $hostInfo = qbhosts --long $hostName
      }
    }
  }
  if ($renderManager -like "*Deadline*") {
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
