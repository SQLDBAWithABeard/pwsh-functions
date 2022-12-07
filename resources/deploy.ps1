$resourceGroupName = "beard-functions"
$location = 'westeurope'
$tags = @{
    environment = "dev"
    owner = "beard"
}
$context = Get-AzContext
if ($context.Subscription.Name -ne 'Beards Microsoft Azure Sponsorship') {
    Write-PSFMessage "Switching to Beards Microsoft Azure Sponsorship subscription" -Level Output
    Select-AzSubscription -SubscriptionName 'Beards Microsoft Azure Sponsorship'
}

if (Get-AzResourceGroup -Name $resourceGroupName  -ErrorAction SilentlyContinue) {
    Write-PSFMessage "$resourceGroupName resource group already exists" -Level Output
} else {
    Write-PSFMessage "Creating $resourceGroupName resource group" -Level Output
    New-AzResourceGroup -Name $resourceGroupName  -Location $location -tags $tags
}

$Name = "beard-functions-{0}" -f (Get-Date -Format "yyyyMMddHHmmss")

$params = @{
    Owner = 'Beard'
    ProjectName = 'BeardProject'
    location = $location
}

Set-Location Git:\pwsh-functions\resources
New-AzResourceGroupDeployment -Name $Name -ResourceGroupName $resourceGroupName  -TemplateFile deploy.bicep -TemplateParameterObject $params -WhatIf