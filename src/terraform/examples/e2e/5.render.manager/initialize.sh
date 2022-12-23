#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

source /etc/profile.d/aaa.sh # https://github.com/Azure/WALinuxAgent/issues/1561

customDataInputFile="/var/lib/waagent/ovf-env.xml"
customDataOutputFile="/var/lib/waagent/scale.auto.sh"
customData=$(xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" $customDataInputFile)
echo $customData | base64 -d > $customDataOutputFile

servicePath="/etc/systemd/system/computeAutoScaler.service"
echo "[Unit]" > $servicePath
echo "Description=Compute Auto Scaler Service" >> $servicePath
echo "After=network-online.target" >> $servicePath
echo "" >> $servicePath
echo "[Service]" >> $servicePath
echo "Environment=renderManager=${renderManager}" >> $servicePath
echo "Environment=scaleSetName=${autoScale.scaleSetName}" >> $servicePath
echo "Environment=resourceGroupName=${autoScale.resourceGroupName}" >> $servicePath
echo "Environment=jobWaitThresholdSeconds=${autoScale.jobWaitThresholdSeconds}" >> $servicePath
echo "Environment=workerIdleDeleteSeconds=${autoScale.workerIdleDeleteSeconds}" >> $servicePath
echo "ExecStart=/bin/bash $customDataOutputFile" >> $servicePath
echo "" >> $servicePath
timerPath="/etc/systemd/system/computeAutoScaler.timer"
echo "[Unit]" > $timerPath
echo "Description=Compute Auto Scaler Timer" >> $timerPath
echo "" >> $timerPath
echo "[Timer]" >> $timerPath
echo "OnUnitActiveSec=${autoScale.detectionIntervalSeconds}" >> $timerPath
echo "AccuracySec=1us" >> $timerPath
echo "" >> $timerPath
echo "[Install]" >> $timerPath
echo "WantedBy=timers.target" >> $timerPath

if [ ${autoScale.enable} == true ]; then
  systemctl --now enable computeAutoScaler
fi

if [ ${cycleCloud.enable} == true ]; then
  az login --identity
  imageList="{"
  imageDefinitions=$(az sig image-definition list --resource-group ${imageResourceGroupName} --gallery-name ${imageGalleryName})
  for imageDefinition in $(echo $imageDefinitions | jq -c .[]); do
    imageDefinitionName=$(echo $imageDefinition | jq -r .name)
    imageVersions=$(az sig image-version list --resource-group ${imageResourceGroupName} --gallery-name ${imageGalleryName} --gallery-image-definition $imageDefinitionName)
    for imageVersion in $(echo $imageVersions | jq -r '.[] | @base64'); do
      _jq() {
        echo $imageVersion | base64 -d | jq -r $1
      }
      imageVersionId=$(_jq .id)
      imageVersionName=$(_jq .name)
      if [ "$imageList" != "{" ]; then
        imageList="$imageList,"
      fi
      imageList="$imageList[Label=\"$imageDefinitionName v$imageVersionName\";Value=\"$imageVersionId\"]"
    done
  done
  imageList="$imageList}"

  cd /opt/cycle_server

  cycleAccountFile="cycle_account.json"
  echo "{" > $cycleAccountFile
  echo "\"Name\": \"Azure\"," >> $cycleAccountFile
  echo "\"Location\": \"${regionName}\"," >> $cycleAccountFile
  echo "\"Provider\": \"azure\"," >> $cycleAccountFile
  echo "\"ProviderId\": \"${subscriptionId}\"," >> $cycleAccountFile
  echo "\"Environment\": \"public\"," >> $cycleAccountFile
  echo "\"DefaultAccount\": true," >> $cycleAccountFile
  echo "\"AzureRMTenantId\": \"${tenantId}\"," >> $cycleAccountFile
  echo "\"AzureRMSubscriptionId\": \"${subscriptionId}\"," >> $cycleAccountFile
  echo "\"AzureRMUseManagedIdentity\": true," >> $cycleAccountFile
  echo "\"RMStorageAccount\": \"${cycleCloud.storageAccountName}\"," >> $cycleAccountFile
  echo "\"RMStorageContainer\": \"cyclecloud\"" >> $cycleAccountFile
  echo "}" >> $cycleAccountFile

  clusterTemplateFile="cluster_template.txt"
  echo "[cluster Render Farm]" > $clusterTemplateFile
  echo "Category = Schedulers" >> $clusterTemplateFile
  echo "IconUrl = https://azrender.blob.core.windows.net/bin/icon.png?sv=2021-04-10&st=2022-01-01T08%3A00%3A00Z&se=2222-12-31T08%3A00%3A00Z&sr=c&sp=r&sig=Q10Ob58%2F4hVJFXfV8SxJNPbGOkzy%2BxEaTd5sJm8BLk8%3D" >> $clusterTemplateFile
  echo "FormLayout = SelectionPanel" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[node defaults]]" >> $clusterTemplateFile
  echo 'KeyPairLocation = ~/.ssh/cyclecloud.pem' >> $clusterTemplateFile
  echo 'Credentials = $credentials' >> $clusterTemplateFile
  echo 'Region = $regionName' >> $clusterTemplateFile
  echo 'SubnetId = $subnetId' >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[nodearray Render Farm]]" >> $clusterTemplateFile
  echo 'ImageName = $imageId' >> $clusterTemplateFile
  echo 'InitialCount = $initialNodeCount' >> $clusterTemplateFile
  echo 'MachineType = $machineType' >> $clusterTemplateFile
  echo 'Interruptible = $useSpotVM' >> $clusterTemplateFile
  echo 'EphemeralOSDisk = $useEphemeralOSDisk' >> $clusterTemplateFile
  echo 'ComputerNamePrefix = $machineNamePrefix' >> $clusterTemplateFile
  echo 'Azure.MaxScaleSetSize = $maxScaleSetSize' >> $clusterTemplateFile
  echo 'EnableTerminateNotification = true' >> $clusterTemplateFile
  echo "CloudInit = '''#!/bin/bash -ex" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  %{ if length(regexall("Qube", renderManager)) > 0 }
    echo "mkdir -p /mnt/qube" >> $clusterTemplateFile
    echo "echo 'render.artist.studio:/qube /mnt/qube nfs defaults 0 0' >> /etc/fstab" >> $clusterTemplateFile
  %{ endif }
  %{ if length(regexall("Deadline", renderManager)) > 0 }
    echo "mkdir -p /mnt/deadline" >> $clusterTemplateFile
    echo "echo 'render.artist.studio:/deadline /mnt/deadline nfs defaults 0 0' >> /etc/fstab" >> $clusterTemplateFile
  %{ endif }
  echo "mkdir -p /mnt/data/write" >> $clusterTemplateFile
  echo "echo 'azrender1.blob.core.windows.net:/azrender1/data /mnt/data/write nfs sec=sys,vers=3,proto=tcp,nolock 0 0' >> /etc/fstab" >> $clusterTemplateFile
  echo "mkdir -p /mnt/data/read" >> $clusterTemplateFile
  echo "echo 'cache.artist.studio:/mnt/data /mnt/data/read nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0' >> /etc/fstab" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "mount -a" >> $clusterTemplateFile
  echo "chmod 777 /mnt/data/read" >> $clusterTemplateFile
  echo "chmod 777 /mnt/data/write" >> $clusterTemplateFile
  echo "'''" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[configuration]]]" >> $clusterTemplateFile
  echo "cyclecloud.monitor_scheduled_events = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[parameters Required]" >> $clusterTemplateFile
  echo "Order = 1" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Virtual Network]]" >> $clusterTemplateFile
  echo "Order = 10" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter regionName]]]" >> $clusterTemplateFile
  echo "Label = Region" >> $clusterTemplateFile
  echo "ParameterType = Cloud.Region" >> $clusterTemplateFile
  echo "DefaultValue = ${regionName}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "Disabled = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter subnetId]]]" >> $clusterTemplateFile
  echo "Label = Subnet" >> $clusterTemplateFile
  echo "ParameterType = Azure.Subnet" >> $clusterTemplateFile
  echo "DefaultValue = ${networkResourceGroupName}/${networkName}/${networkSubnetName}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Virtual Machine]]" >> $clusterTemplateFile
  echo "Order = 11" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter imageId]]]" >> $clusterTemplateFile
  echo "Label = Node Image" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.Dropdown" >> $clusterTemplateFile
  echo "Config.Entries := $imageList" >> $clusterTemplateFile
  echo "DefaultValue = ${imageVersionIdDefault}" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter initialNodeCount]]]" >> $clusterTemplateFile
  echo "Label = Node Count" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.NumberTextBox" >> $clusterTemplateFile
  echo "Config.IntegerOnly = true" >> $clusterTemplateFile
  echo "DefaultValue = 10" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter machineType]]]" >> $clusterTemplateFile
  echo "Label = Node Type" >> $clusterTemplateFile
  echo "ParameterType = Cloud.MachineType" >> $clusterTemplateFile
  echo "DefaultValue = Standard_HB120rs_v2" >> $clusterTemplateFile
  echo "Config.Multiselect = true" >> $clusterTemplateFile
  echo "Required = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter useSpotVM]]]" >> $clusterTemplateFile
  echo "Label = " >> $clusterTemplateFile
  echo "Widget.Label = Use Spot VM Capacity" >> $clusterTemplateFile
  echo "Widget.Plugin = pico.form.BooleanCheckBox" >> $clusterTemplateFile
  echo "DefaultValue = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter useEphemeralOSDisk]]]" >> $clusterTemplateFile
  echo "Label = " >> $clusterTemplateFile
  echo "Widget.Label = Use Ephemeral OS Disk" >> $clusterTemplateFile
  echo "Widget.Plugin = pico.form.BooleanCheckBox" >> $clusterTemplateFile
  echo "DefaultValue = true" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[parameters Advanced]" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Nodes]]" >> $clusterTemplateFile
  echo "Order = 20" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter machineNamePrefix]]]" >> $clusterTemplateFile
  echo "Label = Machine Name Prefix" >> $clusterTemplateFile
  echo "ParameterType = String" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter maxScaleSetSize]]]" >> $clusterTemplateFile
  echo "Label = Max Scale Set Size" >> $clusterTemplateFile
  echo "Config.Plugin = pico.form.NumberTextBox" >> $clusterTemplateFile
  echo "Config.IntegerOnly = true" >> $clusterTemplateFile
  echo "Config.MaxValue = 1000" >> $clusterTemplateFile
  echo "DefaultValue = 40" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[parameters Security]]" >> $clusterTemplateFile
  echo "Order = 21" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  echo "[[[parameter credentials]]]" >> $clusterTemplateFile
  echo "Label = Credentials" >> $clusterTemplateFile
  echo "ParameterType = Cloud.Credentials" >> $clusterTemplateFile
  echo "" >> $clusterTemplateFile
  cyclecloud initialize --url=https://localhost:8443 --username="${adminUsername}" --password="${adminPassword}" --batch --verify-ssl=false
  cyclecloud account create -f $cycleAccountFile
  cyclecloud import_template -f $clusterTemplateFile
  sed -i "s/cycleCloudEnable=false/cycleCloudEnable=true/" /opt/cycle/jetpack/scripts/onPreempt.sh
  sed -i "s/cycleCloudEnable=false/cycleCloudEnable=true/" /opt/cycle/jetpack/scripts/onTerminate.sh
fi
