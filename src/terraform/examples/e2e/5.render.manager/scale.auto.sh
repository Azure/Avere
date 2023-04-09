#!/bin/bash -ex

az login --identity

queuedTasks=0
workerIdleDeleteSeconds=900

if [[ $renderManager == *RoyalRender* ]]; then
  :
fi

if [[ $renderManager == *Qube* ]]; then
  qbDelimiter=";"
  jobFileName="pendingJobs"
  qbjobs --pending --delimit $qbDelimiter --fields id,reason,timesubmit > $jobFileName
  while read pendingJob; do
    if [[ $pendingJob != total* && $pendingJob != id* ]]; then
      jobReason=$(cut -d $qbDelimiter -f 2 <<< "$pendingJob")
      if [[ $jobReason == "no available hosts to run job." ]]; then
        jobSubmitTime=$(cut -d $qbDelimiter -f 3 <<< "$pendingJob")
        jobWaitSecondsStart=$(date -u +%s --date="$jobSubmitTime")
        jobWaitSecondsEnd=$(date -u +%s)
        jobWaitSeconds=$(($jobWaitSecondsEnd - $jobWaitSecondsStart))
        if [ $jobWaitSeconds -gt $jobWaitThresholdSeconds ]; then
          ((queuedTasks++))
        fi
      fi
    fi
  done < $jobFileName
fi

if [[ $renderManager == *Deadline* ]]; then
  activeJobIds=$(deadlinecommand -GetJobIdsFilter Status=Active)
  for jobId in $(echo $activeJobIds); do
    jobDetails=$(deadlinecommand -GetJobDetails $jobId)
    jobProperty="SubmitDate="
    jobSubmitDate=$(echo "$jobDetails" | grep $jobProperty)
    jobSubmitDate=$(echo $${jobSubmitDate#$jobProperty})
    jobWaitSecondsStart=$(date -u +%s --date="$jobSubmitDate")
    jobWaitSecondsEnd=$(date -u +%s)
    jobWaitSeconds=$(($jobWaitSecondsEnd - $jobWaitSecondsStart))
    if [ $jobWaitSeconds -gt $jobWaitThresholdSeconds ]; then
      taskIds=$(deadlinecommand -GetJobTaskIds $jobId)
      for taskId in $(echo $taskIds); do
        task=$(deadlinecommand -GetJobTask $jobId $taskId)
        taskStatus=$(echo "$task" | grep "TaskStatus=")
        taskStatus=$(echo $${taskStatus#*=})
        if [ $taskStatus == "Queued" ]; then
          ((queuedTasks++))
        fi
      done
    fi
  done
fi

if [ $queuedTasks -gt 0 ]; then # Scale Up
  nodeCount=$(az vmss show --resource-group $resourceGroupName --name $scaleSetName --query "sku.capacity")
  nodeCount=$(($nodeCount + $queuedTasks))
  az vmss scale --resource-group $resourceGroupName --name $scaleSetName --new-capacity $nodeCount
else # Scale Down
  if [[ $renderManager == *RoyalRender* ]]; then
    :
  fi

  if [[ $renderManager == *Qube* ]]; then
    qbDelimiter=";"
    hostFileName="jobHosts"
    qbhosts --active --delimit $qbDelimiter > $hostFileName
    while read jobJost; do
      if [[ $jobJost != total* && $jobJost != name* ]]; then
        hostName=$(cut -d $qbDelimiter -f 1 <<< "$jobJost")
        hostInfo=$(qbhosts --long $hostName)
        hostLoad=$(echo "$hostInfo" | grep "host.loadavg_15min=")
        hostLoad=$(echo $${hostLoad#*=})
        hostInstanceId=$(az vmss list-instances --resource-group $resourceGroupName --name $scaleSetName --query "[?osProfile.computerName=='$hostName'].instanceId" --output tsv)
        hostInstanceStartTime=$(az vmss get-instance-view --resource-group $resourceGroupName --name $scaleSetName --instance-id $hostInstanceId --query "statuses[0].time" --output tsv)
        hostInstanceSecondsStart=$(date -u +%s --date="$hostInstanceStartTime")
        hostInstanceSecondsEnd=$(date -u +%s)
        hostInstanceSeconds=$(($hostInstanceSecondsEnd - $hostInstanceSecondsStart))
        if [[ $hostLoad == 0* && $hostInstanceSeconds -gt $workerIdleDeleteSeconds ]]; then
          az vmss delete-instances --resource-group $resourceGroupName --name $scaleSetName --instance-ids $hostInstanceId
        fi
      fi
    done < $hostFileName
  fi

  if [[ $renderManager == *Deadline* ]]; then
    workerNames=$(deadlinecommand -GetSlaveNames)
    for workerName in $(echo $workerNames); do
      workerState=$(deadlinecommand -GetSlaveInfo $workerName SlaveState)
      if [ $workerState == "Idle" ]; then
        worker=$(deadlinecommand -GetSlave $workerName)
        workerProperty="WorkerLastRenderFinishedTime="
        workerIdleStartTime=$(echo "$worker" | grep $workerProperty)
        workerIdleStartTime=$(echo $${workerIdleStartTime#$workerProperty})
        if [ "$workerIdleStartTime" != "" ]; then
          workerIdleSecondsStart=$(date -u +%s --date="$workerIdleStartTime")
          workerIdleSecondsEnd=$(date -u +%s)
          workerIdleSeconds=$(($workerIdleSecondsEnd - $workerIdleSecondsStart))
        else
          workerIdleSeconds=$(deadlinecommand -GetSlaveInfo $workerName UpTimeSeconds)
        fi
        if [ $workerIdleSeconds -gt $workerIdleDeleteSeconds ]; then
          instanceId=$(az vmss list-instances --resource-group $resourceGroupName --name $scaleSetName --query "[?osProfile.computerName=='$workerName'].instanceId" --output tsv)
          az vmss delete-instances --resource-group $resourceGroupName --name $scaleSetName --instance-ids $instanceId
        fi
      fi
    done
  fi
fi
