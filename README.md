# HowTo

Use Powershell

### Create resource group
New-AzureRmResourceGroup -Location <String lacation> -Name <String rgName>

### Deploy infrastructure
New-AzureRmResourceGroupDeployment -Name <String deploymentName> -ResourceGroupName <String rgName> -TemplateFile deploy_infra.json
