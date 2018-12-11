$resourceGroup="anhowe1211d"
#New-AzureRmResourceGroup -Force -Name $resourceGroup -Location "eastus"
New-AzureRmResourceGroup -Force -Name $resourceGroup -Location "westus2"
#New-AzureRmResourceGroupDeployment -Name $resourceGroup -ResourceGroupName $resourceGroup -TemplateFile ./azuredeploy-auto.json -TemplateParameterFile azuredeploy-auto.parameters.ui.anhowe.pw.json
New-AzureRmResourceGroupDeployment -Name $resourceGroup -ResourceGroupName $resourceGroup -TemplateFile ./azuredeploy-auto.json -TemplateParameterFile azuredeploy-auto.parameters.ui.anhowe.ssh.json
